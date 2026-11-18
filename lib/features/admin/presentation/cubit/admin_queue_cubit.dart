import 'dart:async' show unawaited;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_day_close.dart';
import '../../domain/entities/admin_order.dart';
import '../../domain/failures/admin_failure.dart';
import '../../domain/use_cases/close_admin_day_use_case.dart';
import '../../domain/use_cases/confirm_admin_order_payment_use_case.dart';
import '../../domain/use_cases/get_admin_order_detail_use_case.dart';
import '../../domain/use_cases/load_admin_day_close_use_case.dart';
import '../../domain/use_cases/load_admin_queue_use_case.dart';
import '../../domain/use_cases/update_admin_order_status_use_case.dart';
import 'admin_queue_state.dart';

/// SOLID (SRP): único dueño del estado del tab Cocina (§034 — GET
/// /admin/orders del backend §019/022; la cola sale de mocks §038).
/// SINGLETON como OrdersCubit: lo resuelven el pageBuilder de /admin
/// (load por visita) y la pantalla por BlocProvider.value. `load()` =
/// GET /admin/orders?bucket=active|history — la forma del estado ya
/// es la del listado real.
class AdminQueueCubit extends Cubit<AdminQueueState> {
  AdminQueueCubit({
    required this._loadQueue,
    required this._getOrderDetail,
    required this._updateOrderStatus,
    required this._confirmOrderPayment,
    required this._loadDayClose,
    required this._closeDay,
  }) : super(const AdminQueueState());

  final LoadAdminQueueUseCase _loadQueue;
  final GetAdminOrderDetailUseCase _getOrderDetail;
  final UpdateAdminOrderStatusUseCase _updateOrderStatus;
  final ConfirmAdminOrderPaymentUseCase _confirmOrderPayment;
  final LoadAdminDayCloseUseCase _loadDayClose;
  final CloseAdminDayUseCase _closeDay;

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
      final hydrated = _preserveHydrated(full);
      final inActive = state.active.any((o) => o.id == id);
      if (inActive) {
        emit(
          state.copyWith(
            active: [
              for (final o in state.active) o.id == id ? hydrated : o,
            ],
          ),
        );
        return;
      }
      if (state.history.any((o) => o.id == id)) {
        emit(
          state.copyWith(
            history: [
              for (final o in state.history) o.id == id ? hydrated : o,
            ],
          ),
        );
      }
      // No está en ninguna bandeja (history solo carga página 1): se
      // ignora — el detalle sigue con el snapshot del extra.
    });
  }

  /// Núcleo por-orden: si el payload nuevo llega con `modifiers`
  /// vacíos (vista de listado / PATCH §040) pero la copia previa ya
  /// los tiene (detalle §039), conserva los ítems hidratados.
  AdminOrder _preserveHydrated(AdminOrder incoming) {
    final prev = state.orderById(incoming.id);
    return prev != null &&
            prev.items.any((i) => i.modifiers.isNotEmpty) &&
            !incoming.items.any((i) => i.modifiers.isNotEmpty)
        ? incoming.copyWith(items: prev.items)
        : incoming;
  }

  /// Los ítems de una orden son inmutables — si el listado nuevo llega
  /// con `modifiers` vacíos pero la copia previa ya los tiene (el
  /// detalle §039 los hidrató), conserva los ítems hidratados para que
  /// un `load()` concurrente no pise el fetch del detalle.
  List<AdminOrder> _preserveHydratedItems(List<AdminOrder> incoming) =>
      [for (final o in incoming) _preserveHydrated(o)];

  /// Avanza un paso en la matriz §022: PATCH /admin/orders/:id/status.
  /// Las puertas de cliente se conservan como no-op temprano (la matriz
  /// real la exige el backend con 409 — si el estado local estaba viejo
  /// el conflicto resincroniza la cola). Devuelve null en éxito/no-op o
  /// la Failure — la UI elige su toast (convención OrdersCubit §027).
  Future<AdminFailure?> advanceOrder(String id) =>
      _mutateRemote(id, (order) {
        if (order.isTerminal || order.awaitsWebhook) return null;
        if (order.status == OrderStatus.received &&
            order.serviceType == AdminServiceType.pickup &&
            order.paymentStatus != OrderPaymentStatus.paid) {
          return null;
        }
        return switch (order.status) {
          OrderStatus.received => 'confirmed',
          OrderStatus.confirmed => 'preparing',
          OrderStatus.preparing => 'ready',
          OrderStatus.ready => 'done',
          OrderStatus.done || OrderStatus.cancelled => null,
        };
      });

  /// "Registrar pago" — POST /admin/orders/:id/confirm-payment
  /// (§041, backend §022): el servidor cobra Y avanza en el mismo
  /// hecho atómico (pending+presencial+pickup→confirmed, ready→done;
  /// idempotente en `paid`). Las puertas locales se conservan como
  /// no-op — terminal, Nequi (el webhook manda, §036) y pago ya
  /// saldado: el backend responde 200-idempotente pero no gastamos
  /// el request. En falla: resync silencioso de la cola.
  Future<AdminFailure?> markPaid(String id) {
    final current = state.orderById(id);
    if (current == null ||
        current.isTerminal ||
        current.paymentMethod == AdminPaymentMethod.nequi ||
        current.paymentStatus == OrderPaymentStatus.paid) {
      return Future.value();
    }
    return _mutatePayment(id);
  }

  /// Gemelo de `_mutateRemote` para el claim de pago: misma busy
  /// por pedido + el mismo fold (falla → resync; éxito → la entidad
  /// devuelta reemplaza con `_preserveHydrated`). Comparten
  /// `_replaceOrder` — el POST nunca devuelve `cancelled` pero el
  /// helper cubre el caso igual que el PATCH.
  Future<AdminFailure?> _mutatePayment(String id) async {
    if (state.busyOrderIds.contains(id)) return null;
    emit(state.copyWith(busyOrderIds: {...state.busyOrderIds, id}));
    try {
      final result = await _confirmOrderPayment(id);
      if (isClosed) return null;
      final outcome = result.fold(
        (failure) {
          unawaited(load());
          return failure;
        },
        (updated) {
          _replaceOrder(updated);
          return null;
        },
      );
      return outcome;
    } finally {
      if (!isClosed && state.busyOrderIds.contains(id)) {
        emit(
          state.copyWith(busyOrderIds: {...state.busyOrderIds}..remove(id)),
        );
      }
    }
  }

  /// Cancela un pedido no-terminal: PATCH {to: 'cancelled',
  /// cancelReason?} — el motivo (español, user-facing) viaja al
  /// detalle del historial del cliente. El backend además tumba un
  /// pago pending en la misma transacción (§022).
  Future<AdminFailure?> cancelOrder(String id, {String? reason}) {
    final trimmed = reason?.trim();
    return _mutateRemote(
      id,
      (order) => order.isTerminal ? null : 'cancelled',
      cancelReason: trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
  }

  /// Núcleo de las mutaciones de status (§040): busy por pedido +
  /// resolución del `to` en cliente (null = no-op local) + el PATCH
  /// real. En éxito el pedido que devuelve el backend REEMPLAZA al
  /// local — `statusChangedAt` re-sellado ordena el carril nuevo —
  /// conservando los ítems hidratados si la respuesta los trae sin
  /// modifiers (vista de listado). `cancelled` migra al frente del
  /// historial (los demás terminales se quedan en active hasta el
  /// cierre — el endpoint de status no cierra el día). En falla:
  /// resync silencioso de la cola (el 409 dice que el pedido ya
  /// cambió server-side — convención OrdersCubit.cancelOrder §027).
  Future<AdminFailure?> _mutateRemote(
    String id,
    String? Function(AdminOrder order) resolveTo, {
    String? cancelReason,
  }) async {
    if (state.busyOrderIds.contains(id)) return null;
    final current = state.orderById(id);
    final to = current == null ? null : resolveTo(current);
    if (to == null) return null;
    emit(state.copyWith(busyOrderIds: {...state.busyOrderIds, id}));
    try {
      final result = await _updateOrderStatus(
        id,
        to: to,
        cancelReason: cancelReason,
      );
      if (isClosed) return null;
      // El fold va a variable antes del return — devolver la llamada
      // directa dispara unawaited_return_in_try_block (Dart 3.13).
      final outcome = result.fold(
        (failure) {
          unawaited(load());
          return failure;
        },
        (updated) {
          _replaceOrder(updated);
          return null;
        },
      );
      return outcome;
    } finally {
      if (!isClosed && state.busyOrderIds.contains(id)) {
        emit(state.copyWith(busyOrderIds: {...state.busyOrderIds}..remove(id)));
      }
    }
  }

  /// La entidad devuelta por PATCH/POST REEMPLAZA a la local en
  /// ambos buckets — `statusChangedAt` re-sellado ordena el carril
  /// nuevo; `cancelled` migra al frente del historial.
  void _replaceOrder(AdminOrder updated) {
    final hydrated = _preserveHydrated(updated);
    if (updated.status == OrderStatus.cancelled) {
      emit(
        state.copyWith(
          active: state.active.where((o) => o.id != updated.id).toList(),
          history: [
            hydrated,
            ...state.history.where((o) => o.id != updated.id),
          ],
        ),
      );
    } else {
      emit(
        state.copyWith(
          active: [
            for (final o in state.active) o.id == updated.id ? hydrated : o,
          ],
          history: [
            for (final o in state.history) o.id == updated.id ? hydrated : o,
          ],
        ),
      );
    }
  }

  /// Preview del cierre — GET /admin/day-close (§041): el servidor
  /// calcula los terminales sin cerrar; falla → dayCloseFailed (la
  /// pantalla muestra error + Reintentar, no spinner eterno).
  Future<void> loadDayClosePreview() async {
    emit(state.copyWith(dayCloseFailed: false));
    final result = await _loadDayClose();
    if (isClosed) return;
    result.fold(
      (_) => emit(state.copyWith(dayCloseFailed: true)),
      (summary) => emit(state.copyWith(dayClose: () => summary)),
    );
  }

  /// Cierre del periodo — POST /admin/day-close (§041): el snapshot
  /// del servidor queda en `dayClose` como resumen de éxito y los
  /// `done` salen del carril Entregado al FRENTE del historial (el
  /// más reciente primero — la cola por carril los tenía asc). La
  /// animación de salida del AnimatedList juega sola: el diff ve a
  /// todos irse de una. En falla devuelve null — la pantalla toastea
  /// y se queda en el preview.
  Future<AdminDayClose?> closeDay() async {
    if (state.dayCloseBusy) return null;
    emit(state.copyWith(dayCloseBusy: true));
    try {
      final result = await _closeDay();
      if (isClosed) return null;
      // El fold va a variable antes del return — devolver la llamada
      // directa dispara unawaited_return_in_try_block (Dart 3.13).
      final outcome = result.fold(
        (_) => null,
        (summary) {
          final closed = [
            for (final o in state.active)
              if (o.status == OrderStatus.done) o,
          ];
          emit(
            state.copyWith(
              active: [
                for (final o in state.active)
                  if (o.status != OrderStatus.done) o,
              ],
              history: [...closed.reversed, ...state.history],
              dayClose: () => summary,
            ),
          );
          return summary;
        },
      );
      return outcome;
    } finally {
      if (!isClosed && state.dayCloseBusy) {
        emit(state.copyWith(dayCloseBusy: false));
      }
    }
  }
}
