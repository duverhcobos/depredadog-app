import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_day_close.dart';
import '../../domain/entities/admin_order.dart';
import '../../domain/use_cases/get_admin_order_detail_use_case.dart';
import '../../domain/use_cases/load_admin_queue_use_case.dart';
import 'admin_queue_state.dart';

/// SOLID (SRP): único dueño del estado del tab Cocina (§034 — GET
/// /admin/orders del backend §019/022; la cola sale de mocks §038).
/// SINGLETON como OrdersCubit: lo resuelven el pageBuilder de /admin
/// (load por visita) y la pantalla por BlocProvider.value. `load()` =
/// GET /admin/orders?bucket=active|history — la forma del estado ya
/// es la del listado real.
class AdminQueueCubit extends Cubit<AdminQueueState> {
  AdminQueueCubit({required this._loadQueue, required this._getOrderDetail})
    : super(const AdminQueueState());

  final LoadAdminQueueUseCase _loadQueue;
  final GetAdminOrderDetailUseCase _getOrderDetail;

  /// Guardia de reentry — load corre por visita al tab, por pull-
  /// to-refresh y por reintento; un loading paralelo no compite.
  bool _loading = false;

  /// Carga inicial / pull-to-refresh / reload al entrar al tab —
  /// GET /admin/orders (bucket active + history página 1, en
  /// paralelo §038).
  /// dataLoading solo existe sin datos previos: en refresh el
  /// contenido queda pintado (el pull no desmonta el árbol).
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      emit(state.copyWith(dataLoading: state.isEmpty, failed: false));
      final result = await _loadQueue();
      if (isClosed) return;
      result.active.fold(
        // La cola NO se vacía en un refresh fallido — el banner de error
        // viaja sobre los datos viejos (kanban: perder la bandeja ante un
        // fallo de red es peor que mostrar datos stale + aviso). Sin datos
        // previos el mismo flag muestra la vista de error completa.
        (_) => emit(state.copyWith(dataLoading: false, failed: true)),
        (orders) => emit(
          state.copyWith(
            active: _preserveHydratedItems(orders),
            dataLoading: false,
            failed: false,
          ),
        ),
      );
      result.history.fold(
        // Historial provisional (pantalla del ícono) — su falla no tiene
        // superficie visual hoy; conserva los datos previos en silencio.
        (_) {},
        (page) => emit(state.copyWith(history: _preserveHydratedItems(page.items))),
      );
    } finally {
      _loading = false;
    }
  }

  /// GET /admin/orders/:id (§039) — al abrir el detalle: la comanda
  /// completa (modifiers) + estado fresco reemplazan el snapshot del
  /// listado. Falla silenciosa: el detalle ya muestra el snapshot.
  Future<void> refreshOrder(String id) async {
    final result = await _getOrderDetail(id);
    if (isClosed) return;
    result.fold((_) {}, (full) {
      final inActive = state.active.any((o) => o.id == id);
      if (inActive) {
        emit(
          state.copyWith(
            active: [for (final o in state.active) o.id == id ? full : o],
          ),
        );
        return;
      }
      if (state.history.any((o) => o.id == id)) {
        emit(
          state.copyWith(
            history: [for (final o in state.history) o.id == id ? full : o],
          ),
        );
      }
      // No está en ninguna bandeja (history solo carga página 1): se
      // ignora — el detalle sigue con el snapshot del extra.
    });
  }

  /// Los ítems de una orden son inmutables — si el listado nuevo llega
  /// con `modifiers` vacíos pero la copia previa ya los tiene (el
  /// detalle §039 los hidrató), conserva los ítems hidratados para que
  /// un `load()` concurrente no pise el fetch del detalle.
  List<AdminOrder> _preserveHydratedItems(List<AdminOrder> incoming) => [
    for (final o in incoming)
      () {
        final prev = state.orderById(o.id);
        return prev != null &&
                prev.items.any((i) => i.modifiers.isNotEmpty) &&
                !o.items.any((i) => i.modifiers.isNotEmpty)
            ? o.copyWith(items: prev.items)
            : o;
      }(),
  ];

  /// Avanza un paso en la matriz del §022: received→confirmed→
  /// preparing→ready→done; terminal → no-op. En integración =
  /// PATCH /admin/orders/:id/status {to}. Tres puertas de pago que
  /// el backend rechaza con 409 (el mock las reproduce como no-op):
  /// la recogida no se confirma sin cobrar (pickup nunca acepta
  /// efectivo — decisión §036), el done exige paid, y el cobro
  /// Nequi NO se adelanta — solo el webhook lo confirma (§036).
  Future<void> advanceOrder(String id) => _mutateOrder(id, (order) {
    if (order.isTerminal || order.awaitsWebhook) return null;
    if (order.status == OrderStatus.received &&
        order.serviceType == AdminServiceType.pickup &&
        order.paymentStatus != OrderPaymentStatus.paid) {
      return null;
    }
    final next = switch (order.status) {
      OrderStatus.received => OrderStatus.confirmed,
      OrderStatus.confirmed => OrderStatus.preparing,
      OrderStatus.preparing => OrderStatus.ready,
      OrderStatus.ready => OrderStatus.done,
      OrderStatus.done || OrderStatus.cancelled => order.status,
    };
    return order.copyWith(status: next);
  });

  /// "Registrar pago" — paymentStatus pending/failed → paid (POST
  /// /admin/orders/:id/confirm-payment en integración, claim
  /// atómico). Failed también se cobra: un pago rechazado sigue
  /// debiendo — la matriz lo trata como pendiente de cobro, no
  /// como saldado (revisor-ui §035). No-op en terminal o paid — y
  /// en Nequi SIEMPRE (§036): el cobro dentro de la app lo confirma
  /// el webhook, nadie lo registra a mano.
  /// Cobrar era el ÚNICO bloqueo — un toque también AVANZA el
  /// estado (§036, decisión del dueño): la recogida presencial
  /// pendiente entra directo a Confirmado; el Listo cierra de una
  /// (mesa que paga y se va, delivery cobrado en la puerta).
  Future<void> markPaid(String id) => _mutateOrder(id, (order) {
    if (order.isTerminal ||
        order.paymentMethod == AdminPaymentMethod.nequi ||
        order.paymentStatus == OrderPaymentStatus.paid) {
      return null;
    }
    final next = switch (order.status) {
      OrderStatus.received
          when order.serviceType == AdminServiceType.pickup =>
        OrderStatus.confirmed,
      OrderStatus.ready => OrderStatus.done,
      _ => order.status,
    };
    return order.copyWith(
      paymentStatus: OrderPaymentStatus.paid,
      status: next,
    );
  });

  /// Cancela un pedido no-terminal (PATCH status {to: cancelled,
  /// cancelReason?} en integración) — el motivo es opcional y queda
  /// en la entidad para que el detalle/historial lo lean.
  Future<void> cancelOrder(String id, {String? reason}) =>
      _mutateOrder(id, (order) {
        if (order.isTerminal) return null;
        final trimmed = reason?.trim();
        return order.copyWith(
          status: OrderStatus.cancelled,
          cancelReason: trimmed == null || trimmed.isEmpty ? null : trimmed,
        );
      });

  /// Núcleo de las operaciones (§035): busy por pedido (el
  /// spinner inline del botón — adelanta la guardia anti doble-tap
  /// del UPDATE condicional del backend) y el swap de bucket cuando
  /// el resultado es terminal. `mutation` devuelve la entidad
  /// actualizada o null = no-op (terminal / pago ya hecho).
  /// PROVISIONAL (§038): las operaciones mutan SOLO el estado local hasta
  /// sus ciclos de integración — PATCH /admin/orders/:id/status,
  /// POST /admin/orders/:id/confirm-payment. El delay simulado se quita
  /// cuando el endpoint responda de verdad.
  Future<void> _mutateOrder(
    String id,
    AdminOrder? Function(AdminOrder order) mutation,
  ) async {
    // Guarda de re-entrada (convención CheckoutCubit): la UI deja el
    // botón vivo bajo IgnorePointer y el cubit es quien ignora el
    // segundo toque — un busy ya en curso sobre el pedido es no-op.
    if (state.busyOrderIds.contains(id)) return;
    emit(state.copyWith(busyOrderIds: {...state.busyOrderIds, id}));
    try {
      if (isClosed) return;
      final busy = {...state.busyOrderIds}..remove(id);
      final current = state.orderById(id);
      final updated = current == null ? null : mutation(current);
      if (updated == null) {
        emit(state.copyWith(busyOrderIds: busy));
        return;
      }
      if (updated.status == OrderStatus.cancelled) {
        // Solo el cancelado sale de Cocina de una (decisión §022);
        // el done se queda en `active` — vive en el carril
        // Entregado hasta que el cierre lo archive.
        emit(
          state.copyWith(
            active: state.active.where((o) => o.id != id).toList(),
            history: [updated, ...state.history.where((o) => o.id != id)],
            busyOrderIds: busy,
          ),
        );
      } else {
        emit(
          state.copyWith(
            active: [for (final o in state.active) o.id == id ? updated : o],
            history: [for (final o in state.history) o.id == id ? updated : o],
            busyOrderIds: busy,
          ),
        );
      }
    } finally {
      // El busy nunca queda prendido: si la mutación no corrió
      // (cubit cerrado a mitad de camino ya está cubierto arriba)
      // el pedido no puede quedar congelado con spinner eterno.
      if (!isClosed && state.busyOrderIds.contains(id)) {
        emit(state.copyWith(busyOrderIds: {...state.busyOrderIds}..remove(id)));
      }
    }
  }

  /// Preview del cierre (GET /admin/day-close en integración):
  /// calcula el resumen de los done-sin-cerrar + cancelados de la
  /// jornada (en mock: los cancelled actuales del history).
  void loadDayClosePreview() {
    final done = [
      for (final o in state.active)
        if (o.status == OrderStatus.done) o,
    ];
    final cancelled = [
      for (final o in state.history)
        if (o.status == OrderStatus.cancelled) o,
    ];
    final byMethod = <String, ({int count, int amount})>{};
    for (final o in done) {
      final m = o.paymentMethod.name;
      final cur = byMethod[m] ?? (count: 0, amount: 0);
      byMethod[m] = (count: cur.count + 1, amount: cur.amount + o.total);
    }
    emit(
      state.copyWith(
        dayClose: () => AdminDayClose(
          orderCount: done.length,
          totalAmount: done.fold(0, (acc, o) => acc + o.total),
          byMethod: [
            for (final e in byMethod.entries)
              AdminDayCloseMethod(
                method: e.key,
                count: e.value.count,
                amount: e.value.amount,
              ),
          ],
          cancelledCount: cancelled.length,
          cancelledAmount: cancelled.fold(0, (acc, o) => acc + o.total),
        ),
      ),
    );
  }

  /// Cierre del día (POST /admin/day-close en integración): los
  /// done del activo se archivan al history (el mock simula el
  /// `day_close_id` que el backend estampa); cancelados ya viven
  /// ahí. Devuelve el resumen para la pantalla de éxito.
  Future<AdminDayClose?> closeDay() async {
    if (state.dayCloseBusy) return null;
    emit(state.copyWith(dayCloseBusy: true));
    try {
      if (isClosed) return null;
      loadDayClosePreview();
      final summary = state.dayClose;
      emit(
        state.copyWith(
          active: [
            for (final o in state.active)
              if (o.status != OrderStatus.done) o,
          ],
          history: [
            for (final o in state.active)
              if (o.status == OrderStatus.done) o,
            ...state.history,
          ],
          dayCloseBusy: false,
        ),
      );
      return summary;
    } finally {
      if (!isClosed && state.dayCloseBusy) {
        emit(state.copyWith(dayCloseBusy: false));
      }
    }
  }
}
