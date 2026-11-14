import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../cart/domain/entities/cart_modifier.dart';
import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_day_close.dart';
import '../../domain/entities/admin_order.dart';
import 'admin_queue_state.dart';

/// SOLID (SRP): único dueño del estado del tab Cocina (§034 — solo
/// presentación, patrón §026/§030: contrato real, datos ficticios).
/// SINGLETON como OrdersCubit: lo resuelven el pageBuilder de /admin
/// (load por visita) y la pantalla por BlocProvider.value. En
/// integración `load()` = GET /admin/orders?bucket=active|history —
/// la forma del estado ya es la del listado real.
class AdminQueueCubit extends Cubit<AdminQueueState> {
  AdminQueueCubit({List<AdminOrder>? mockActive, List<AdminOrder>? mockHistory})
    // List.of: las inyecciones de test pueden ser const — los mocks
    // se mutan como "servidor" en cada operación (§035).
    : _mockActive = mockActive != null ? List.of(mockActive) : _defaultActive(),
      _mockHistory = mockHistory != null
          ? List.of(mockHistory)
          : _defaultHistory(),
      super(const AdminQueueState());

  final List<AdminOrder> _mockActive;
  final List<AdminOrder> _mockHistory;

  /// Guardia de reentry — load corre por visita al tab, por pull-
  /// to-refresh y por reintento; un loading paralelo no compite.
  bool _loading = false;

  /// Carga inicial / pull-to-refresh / reload al entrar al tab —
  /// 400ms de latencia simulada (misma convención del mock §023).
  /// dataLoading solo existe sin datos previos: en refresh el
  /// contenido queda pintado (el pull no desmonta el árbol).
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      emit(state.copyWith(dataLoading: state.isEmpty, failed: false));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (isClosed) return;
      emit(
        state.copyWith(
          active: _mockActive,
          history: _mockHistory,
          dataLoading: false,
        ),
      );
    } finally {
      _loading = false;
    }
  }

  /// Latencia simulada de una operación — la misma de load()
  /// (convención §023); el busy inline dura lo que el mock tarda.
  static const _actionLatency = Duration(milliseconds: 400);

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

  /// Núcleo de las operaciones mock (§035): busy por pedido (el
  /// spinner inline del botón — adelanta la guardia anti doble-tap
  /// del UPDATE condicional del backend), latencia, y el swap de
  /// bucket cuando el resultado es terminal. `mutation` devuelve la
  /// entidad actualizada o null = no-op (terminal / pago ya hecho).
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
      await Future<void>.delayed(_actionLatency);
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
      _syncMocks();
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
      await Future<void>.delayed(_actionLatency);
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
      _syncMocks();
      return summary;
    } finally {
      if (!isClosed && state.dayCloseBusy) {
        emit(state.copyWith(dayCloseBusy: false));
      }
    }
  }

  /// Los mocks son el "servidor" de la fase presentación: la
  /// mutación persiste en ellos para que el próximo load() (pull-
  /// to-refresh, re-entry al tab) la vea y no resucite pedidos ya
  /// operados — sin esto un pull haría reaparecer en Activos lo que
  /// el dueño acababa de completar o cancelar.
  void _syncMocks() {
    _mockActive
      ..clear()
      ..addAll(state.active);
    _mockHistory
      ..clear()
      ..addAll(state.history);
  }

  /// Cola viva mock (§036): todos los carriles poblados con todas
  /// las variantes — la puerta de confirmación queda a la vista en
  /// Pendiente: la recogida PRESENCIAL sin cobrar (mostrador/
  /// teléfono, pending/failed) se bloquea a "Registrar pago" y el
  /// resto confirma libre; la recogida ONLINE solo acepta Nequi —
  /// se congela hasta el webhook (pending = rótulo de espera,
  /// failed = solo cancelar; ya pagado fluye normal).
  /// canales online/presencial, serviceType pickup/delivery/
  /// dineIn, pago efectivo/transferencia/nequi en los 3 estados. El
  /// cierre muestra el desglose de métodos.
  static List<AdminOrder> _defaultActive() {
    final now = DateTime.now();
    return [
      // PENDIENTE — online delivery, transfer pendiente. El caso
      // "me escriben por WhatsApp que ya pagaron" del dueño.
      AdminOrder(
        id: 'adm-1',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.delivery,
        status: OrderStatus.received,
        items: const [
          OrderItem(
            productId: 'p-depredador',
            productSlug: 'depredador',
            name: 'El Depredador',
            quantity: 2,
            unitPrice: 25000,
            includedNames: [
              'Pan artesanal', 'Salchicha', 'Papitas', 'Queso', 'Salsas',
            ],
            modifiers: [
              CartModifier(
                optionId: 'ing-cebolla',
                optionName: 'Cebolla',
                action: CartModifierAction.removed,
                priceDelta: 0,
              ),
              CartModifier(
                optionId: 'ex-queso',
                optionName: 'Queso cheddar',
                action: CartModifierAction.added,
                priceDelta: 2500,
                group: CartModifierGroup.extra,
              ),
              CartModifier(
                optionId: 'sa-pina',
                optionName: 'Piña',
                action: CartModifierAction.added,
                priceDelta: 0,
                group: CartModifierGroup.sauce,
              ),
            ],
          ),
          OrderItem(
            productId: 'p-papas',
            productSlug: 'manada-papas',
            name: 'Manada de papas',
            quantity: 1,
            unitPrice: 6000,
            includedNames: ['Papas criollas', 'Queso', 'Salsas de la casa'],
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.pending,
        subtotal: 56000,
        deliveryFee: 5000,
        placedAt: now.subtract(const Duration(minutes: 12)),
        customerName: 'Ana Uno',
        addressLabel: 'Casa',
        landmark: 'Portón negro frente a la cancha',
        neighborhood: 'Barrio La Esperanza',
        hasLocationPin: true,
        locationUrl: 'https://maps.app.goo.gl/s5RiFni6LsV4Ptmj9',
        locationLat: 6.2442,
        locationLng: -75.5812,
        contactPhone: '3001234567',
        note: 'Sin picante — es para el niño',
      ),
      // CONFIRMADO — dine_in Mesa 3, cash pendiente (cobrar no es
      // la acción de card en estados tempranos — en mesa se sirve
      // antes de cobrar).
      AdminOrder(
        id: 'adm-2',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.dineIn,
        status: OrderStatus.confirmed,
        statusChangedAt: now.subtract(const Duration(minutes: 9)),
        items: const [
          OrderItem(
            productId: 'p-cachorro',
            productSlug: 'cachorro',
            name: 'El Cachorro',
            quantity: 1,
            unitPrice: 14000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.pending,
        subtotal: 14000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 4)),
        tableLabel: 'Mesa 3',
      ),
      // CONFIRMADO — presencial mostrador pagado (adm-4 pasa de
      // received a confirmed: el backend §019 crea presenciales ya
      // confirmados — un 'received' presencial es contrato viejo).
      AdminOrder(
        id: 'adm-4',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.pickup,
        status: OrderStatus.confirmed,
        statusChangedAt: now.subtract(const Duration(minutes: 8)),
        items: const [
          OrderItem(
            productId: 'p-coyote',
            productSlug: 'coyote',
            name: 'El Coyote',
            quantity: 2,
            unitPrice: 18000,
            includedNames: [
              'Pan artesanal', 'Salchicha', 'Papitas', 'Queso', 'Salsas',
            ],
            modifiers: [
              CartModifier(
                optionId: 'ing-cebolla',
                optionName: 'Cebolla',
                action: CartModifierAction.removed,
                priceDelta: 0,
              ),
              CartModifier(
                optionId: 'sa-pina',
                optionName: 'Piña',
                action: CartModifierAction.added,
                priceDelta: 0,
                group: CartModifierGroup.sauce,
              ),
            ],
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 36000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 1)),
      ),
      // CONFIRMADO — online delivery NEQUI ya pagado: el webhook
      // llegó primero y confirmó — el pedido fluye normal (acción
      // "Preparar"); contracara de los Nequi congelados en
      // Pendiente (§036).
      AdminOrder(
        id: 'adm-32',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.delivery,
        status: OrderStatus.confirmed,
        statusChangedAt: now.subtract(const Duration(minutes: 7)),
        items: const [
          OrderItem(
            productId: 'p-depredador',
            productSlug: 'depredador',
            name: 'El Depredador',
            quantity: 1,
            unitPrice: 25000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.nequi,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 25000,
        deliveryFee: 3000,
        placedAt: now.subtract(const Duration(minutes: 3)),
        customerName: 'Wanda Treintaidós',
        addressLabel: 'Trabajo',
        landmark: 'Edificio azul de la esquina, segundo piso',
        neighborhood: 'Barrio El Centro',
        contactPhone: '3019876543',
      ),
      // PREPARANDO — Mesa 5 (la orden grande) dine_in cash paid:
      // 1× de cada producto del menú (7 líneas) — cubre el resumen
      // largo de la card (maxLines 2 → la cola real trunca con "…").
      AdminOrder(
        id: 'adm-7',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.dineIn,
        status: OrderStatus.preparing,
        statusChangedAt: now.subtract(const Duration(minutes: 5)),
        items: const [
          OrderItem(
            productId: 'p-depredador',
            productSlug: 'depredador',
            name: 'El Depredador',
            quantity: 1,
            unitPrice: 25000,
            includedNames: [
              'Pan artesanal', 'Salchicha', 'Papitas', 'Queso', 'Salsas',
            ],
            modifiers: [
              CartModifier(
                optionId: 'ing-cebolla',
                optionName: 'Cebolla',
                action: CartModifierAction.removed,
                priceDelta: 0,
              ),
              CartModifier(
                optionId: 'ex-tocineta',
                optionName: 'Tocineta',
                action: CartModifierAction.added,
                priceDelta: 3500,
                group: CartModifierGroup.extra,
              ),
            ],
          ),
          OrderItem(
            productId: 'p-carnicero',
            productSlug: 'carnicero',
            name: 'El Carnicero',
            quantity: 1,
            unitPrice: 17000,
            includedNames: [
              'Pan artesanal', 'Salchicha', 'Papitas', 'Queso', 'Salsas',
            ],
            modifiers: [
              CartModifier(
                optionId: 'ex-queso',
                optionName: 'Queso cheddar',
                action: CartModifierAction.added,
                priceDelta: 2500,
                group: CartModifierGroup.extra,
              ),
            ],
          ),
          OrderItem(
            productId: 'p-coyote',
            productSlug: 'coyote',
            name: 'El Coyote',
            quantity: 1,
            unitPrice: 18000,
            includedNames: [
              'Pan artesanal', 'Salchicha', 'Papitas', 'Queso', 'Salsas',
            ],
          ),
          OrderItem(
            productId: 'p-ave',
            productSlug: 'ave-presa',
            name: 'Ave de Presa',
            quantity: 1,
            unitPrice: 18000,
            modifiers: [
              CartModifier(
                optionId: 'ing-tomate',
                optionName: 'Tomate',
                action: CartModifierAction.removed,
                priceDelta: 0,
              ),
              CartModifier(
                optionId: 'sa-pina',
                optionName: 'Piña',
                action: CartModifierAction.added,
                priceDelta: 0,
                group: CartModifierGroup.sauce,
              ),
            ],
          ),
          OrderItem(
            productId: 'p-trampa',
            productSlug: 'trampa',
            name: 'La Trampa',
            quantity: 1,
            unitPrice: 16000,
            includedNames: [
              'Pan artesanal', 'Salchicha', 'Papitas', 'Queso', 'Salsas',
            ],
            modifiers: [
              CartModifier(
                optionId: 'ing-repollo',
                optionName: 'Repollo',
                action: CartModifierAction.removed,
                priceDelta: 0,
              ),
            ],
          ),
          OrderItem(
            productId: 'p-cachorro',
            productSlug: 'cachorro',
            name: 'El Cachorro',
            quantity: 1,
            unitPrice: 14000,
          ),
          OrderItem(
            productId: 'p-papas',
            productSlug: 'manada-papas',
            name: 'Manada de Papas',
            quantity: 1,
            unitPrice: 10000,
            includedNames: ['Papas criollas', 'Queso', 'Salsas de la casa'],
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 118000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 8)),
        tableLabel: 'Mesa 5',
        note: 'Uno sin cebolla porfa',
      ),
      // PENDIENTE — online pickup NEQUI FALLIDO: el webhook ya
      // rechazó el cobro — online pickup SOLO acepta Nequi (§036:
      // efectivo/transfer dejan al cliente ghostear la producción);
      // sin botones, la única salida es cancelar.
      AdminOrder(
        id: 'adm-9',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.pickup,
        status: OrderStatus.received,
        items: const [
          OrderItem(
            productId: 'p-coyote',
            productSlug: 'coyote',
            name: 'El Coyote',
            quantity: 2,
            unitPrice: 18000,
          ),
          OrderItem(
            productId: 'p-papas',
            productSlug: 'manada-papas',
            name: 'Manada de papas',
            quantity: 1,
            unitPrice: 10000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.nequi,
        paymentStatus: OrderPaymentStatus.failed,
        subtotal: 46000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 3)),
        customerName: 'Daniela Cuatro',
        contactPhone: '3171234567',
      ),
      // PENDIENTE — online delivery, transfer pendiente, pedido
      // de ítem único grande.
      AdminOrder(
        id: 'adm-10',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.delivery,
        status: OrderStatus.received,
        items: const [
          OrderItem(
            productId: 'p-trampa',
            productSlug: 'trampa',
            name: 'La Trampa',
            quantity: 3,
            unitPrice: 16000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.pending,
        subtotal: 48000,
        deliveryFee: 4000,
        placedAt: now.subtract(const Duration(minutes: 2)),
        customerName: 'Elena Cinco',
        addressLabel: 'Casa',
        landmark: 'Al lado de la tienda Don Pedro',
        neighborhood: 'Barrio San José',
        hasLocationPin: true,
        locationUrl: 'https://maps.app.goo.gl/s5RiFni6LsV4Ptmj9',
        locationLat: 6.2518,
        locationLng: -75.5636,
        contactPhone: '3023456789',
      ),
      // PENDIENTE — online delivery PAGADO: prepaid, confirma sin
      // fricción (contracara de los delivery sin cobrar).
      AdminOrder(
        id: 'adm-20',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.delivery,
        status: OrderStatus.received,
        items: const [
          OrderItem(
            productId: 'p-ave',
            productSlug: 'ave-presa',
            name: 'Ave de Presa',
            quantity: 1,
            unitPrice: 18000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 18000,
        deliveryFee: 3000,
        placedAt: now.subtract(const Duration(minutes: 11)),
        customerName: 'Mario Doce',
        addressLabel: 'Casa de mi mamá',
        landmark: 'Casa verde de dos pisos',
        neighborhood: 'Barrio La Floresta',
        contactPhone: '3104567890',
      ),
      // PENDIENTE — online delivery CONTRAENTREGA (efectivo en la
      // puerta): pidió por la app y paga al recibir — SÍ confirma
      // porque la entrega la hace el dueño y nada sale sin él; el
      // cobro se registra con "Registrar pago" en la puerta.
      AdminOrder(
        id: 'adm-28',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.delivery,
        status: OrderStatus.received,
        items: const [
          OrderItem(
            productId: 'p-carnicero',
            productSlug: 'carnicero',
            name: 'El Carnicero',
            quantity: 1,
            unitPrice: 17000,
          ),
          OrderItem(
            productId: 'p-papas',
            productSlug: 'manada-papas',
            name: 'Manada de papas',
            quantity: 1,
            unitPrice: 6000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.pending,
        subtotal: 23000,
        deliveryFee: 3000,
        placedAt: now.subtract(const Duration(minutes: 7)),
        customerName: 'Pablo Veintiocho',
        addressLabel: 'Casa',
        landmark: 'Frente a la iglesia',
        neighborhood: 'Barrio El Carmen',
        hasLocationPin: true,
        locationUrl: 'https://maps.app.goo.gl/s5RiFni6LsV4Ptmj9',
        locationLat: 6.2309,
        locationLng: -75.5901,
        contactPhone: '3115678901',
      ),
      // PENDIENTE — online pickup NEQUI esperando webhook (§036):
      // el cobro dentro de la app no lo toca el dueño — la card
      // muestra el rótulo de espera, sin botones.
      AdminOrder(
        id: 'adm-29',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.pickup,
        status: OrderStatus.received,
        items: const [
          OrderItem(
            productId: 'p-ave',
            productSlug: 'ave-presa',
            name: 'Ave de Presa',
            quantity: 2,
            unitPrice: 18000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.nequi,
        paymentStatus: OrderPaymentStatus.pending,
        subtotal: 36000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 6)),
        customerName: 'Tomás Veintinueve',
        contactPhone: '3182345678',
      ),
      // PENDIENTE — online delivery NEQUI esperando webhook: la
      // regla congela TAMBIÉN el domicilio — aunque el dueño
      // entregue, ni Confirmar ni Registrar pago existen hasta
      // que el webhook hable (decisión §036).
      AdminOrder(
        id: 'adm-30',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.delivery,
        status: OrderStatus.received,
        items: const [
          OrderItem(
            productId: 'p-trampa',
            productSlug: 'trampa',
            name: 'La Trampa',
            quantity: 2,
            unitPrice: 16000,
            includedNames: [
              'Pan artesanal', 'Salchicha', 'Papitas', 'Queso', 'Salsas',
            ],
            modifiers: [
              CartModifier(
                optionId: 'ing-repollo',
                optionName: 'Repollo',
                action: CartModifierAction.removed,
                priceDelta: 0,
              ),
              CartModifier(
                optionId: 'ex-tocineta',
                optionName: 'Tocineta',
                action: CartModifierAction.added,
                priceDelta: 3500,
                group: CartModifierGroup.extra,
              ),
            ],
          ),
        ],
        paymentMethod: AdminPaymentMethod.nequi,
        paymentStatus: OrderPaymentStatus.pending,
        subtotal: 32000,
        deliveryFee: 4000,
        placedAt: now.subtract(const Duration(minutes: 5)),
        customerName: 'Uriel Treinta',
        addressLabel: 'Oficina',
        landmark: 'Local 4, centro comercial La Esquina',
        neighborhood: 'Barrio El Centro',
        contactPhone: '3126789012',
      ),
      // PENDIENTE — online pickup NEQUI FALLIDO: el webhook ya
      // reportó el rechazo — sin botones de avance ni cobro, la
      // única salida es cancelar (decisión §036).
      AdminOrder(
        id: 'adm-31',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.pickup,
        status: OrderStatus.received,
        items: const [
          OrderItem(
            productId: 'p-cachorro',
            productSlug: 'cachorro',
            name: 'El Cachorro',
            quantity: 1,
            unitPrice: 14000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.nequi,
        paymentStatus: OrderPaymentStatus.failed,
        subtotal: 14000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 2)),
        customerName: 'Valeria Treintaiuno',
        contactPhone: '3193456789',
      ),
      // PENDIENTE — online pickup NEQUI PAGADO: el webhook ya
      // confirmó — la recogida sí confirma (contracara de los
      // Nequi congelados).
      AdminOrder(
        id: 'adm-21',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.pickup,
        status: OrderStatus.received,
        items: const [
          OrderItem(
            productId: 'p-trampa',
            productSlug: 'trampa',
            name: 'La Trampa',
            quantity: 1,
            unitPrice: 16000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.nequi,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 16000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 10)),
        customerName: 'Nora Trece',
        contactPhone: '3204567890',
        note: 'La recoge mi hermano',
      ),
      // CONFIRMADO NATURAL — presencial delivery sin cobrar
      // (pedido tomado por teléfono): el dueño ES el confirmador —
      // nace confirmed como la mesa, nunca pisa Pendiente (§036);
      // el cobro se resuelve en la puerta al entregar.
      AdminOrder(
        id: 'adm-22',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.delivery,
        status: OrderStatus.confirmed,
        statusChangedAt: now.subtract(const Duration(minutes: 6)),
        items: const [
          OrderItem(
            productId: 'p-depredador',
            productSlug: 'depredador',
            name: 'El Depredador',
            quantity: 1,
            unitPrice: 25000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.pending,
        subtotal: 25000,
        deliveryFee: 3000,
        placedAt: now.subtract(const Duration(minutes: 9)),
        customerName: 'Óscar Catorce',
        addressLabel: 'Casa',
        landmark: 'Portón blanco con reja',
        neighborhood: 'Barrio La Esperanza',
        hasLocationPin: true,
        locationUrl: 'https://maps.app.goo.gl/s5RiFni6LsV4Ptmj9',
        locationLat: 6.2701,
        locationLng: -75.5723,
        contactPhone: '3137890123',
      ),
      // CONFIRMADO NATURAL — presencial dineIn cash pendiente
      // (Mesa 4): el dueño la tomó → nace confirmed (§036); en
      // mesa se sirve primero y se cobra cuando se van.
      AdminOrder(
        id: 'adm-23',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.dineIn,
        status: OrderStatus.confirmed,
        statusChangedAt: now.subtract(const Duration(minutes: 5)),
        items: const [
          OrderItem(
            productId: 'p-carnicero',
            productSlug: 'carnicero',
            name: 'El Carnicero',
            quantity: 2,
            unitPrice: 17000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.pending,
        subtotal: 34000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 8)),
        tableLabel: 'Mesa 4',
      ),
      // CONFIRMADO NATURAL — presencial dineIn TRANSFER pendiente
      // (Mesa 6 paga QR al final): misma regla — nace confirmed,
      // el cobro se resuelve al cerrar la cuenta.
      AdminOrder(
        id: 'adm-27',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.dineIn,
        status: OrderStatus.confirmed,
        statusChangedAt: now.subtract(const Duration(minutes: 4)),
        items: const [
          OrderItem(
            productId: 'p-cachorro',
            productSlug: 'cachorro',
            name: 'El Cachorro',
            quantity: 3,
            unitPrice: 14000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.pending,
        subtotal: 42000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 7)),
        tableLabel: 'Mesa 6',
      ),
      // PENDIENTE — online pickup NEQUI esperando webhook: online
      // pickup SOLO acepta Nequi (§036 — el efectivo/transfer deja
      // producción perdida si no recogen). La card espera el
      // webhook — sin botones.
      AdminOrder(
        id: 'adm-24',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.pickup,
        status: OrderStatus.received,
        items: const [
          OrderItem(
            productId: 'p-coyote',
            productSlug: 'coyote',
            name: 'El Coyote',
            quantity: 1,
            unitPrice: 18000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.nequi,
        paymentStatus: OrderPaymentStatus.pending,
        subtotal: 18000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 5)),
        customerName: 'Sara Quince',
        contactPhone: '3215678901',
      ),
      // PENDIENTE — presencial pickup (mostrador) cash PENDIENTE:
      // en mostrador se cobra al tomar — sin cobrar no entra a
      // cocina → BLOQUEADO, "Registrar pago". Variante mock: el presencial
      // podría nacer received si quedó sin cobrar (§022 la decide).
      AdminOrder(
        id: 'adm-25',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.pickup,
        status: OrderStatus.received,
        items: const [
          OrderItem(
            productId: 'p-ave',
            productSlug: 'ave-presa',
            name: 'Ave de Presa',
            quantity: 1,
            unitPrice: 18000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.pending,
        subtotal: 18000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 4)),
      ),
      // PENDIENTE — presencial pickup (mostrador) cash PAGADO:
      // cobrado al tomarlo → SÍ confirma.
      AdminOrder(
        id: 'adm-26',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.pickup,
        status: OrderStatus.received,
        items: const [
          OrderItem(
            productId: 'p-trampa',
            productSlug: 'trampa',
            name: 'La Trampa',
            quantity: 1,
            unitPrice: 16000,
          ),
          OrderItem(
            productId: 'p-papas',
            productSlug: 'manada-papas',
            name: 'Manada de papas',
            quantity: 1,
            unitPrice: 10000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 26000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 3)),
      ),
      // PENDIENTE — presencial pickup por TELÉFONO, transfer
      // PENDIENTE: el cliente dice "ya te transfiero" — presencial
      // sí admite transfer manual (el dueño la certifica con
      // "Registrar pago"); sin plata no entra a cocina → BLOQUEADO.
      // La prohibición de transfer solo es para online (§036).
      AdminOrder(
        id: 'adm-33',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.pickup,
        status: OrderStatus.received,
        items: const [
          OrderItem(
            productId: 'p-carnicero',
            productSlug: 'carnicero',
            name: 'El Carnicero',
            quantity: 1,
            unitPrice: 17000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.pending,
        subtotal: 17000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 1)),
      ),
      // CONFIRMADO — online delivery YA PAGADO por adelantado: la
      // cocina prepara sin preocuparse por el cobro.
      AdminOrder(
        id: 'adm-11',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.delivery,
        status: OrderStatus.confirmed,
        statusChangedAt: now.subtract(const Duration(minutes: 3)),
        items: const [
          OrderItem(
            productId: 'p-ave',
            productSlug: 'ave-presa',
            name: 'Ave de Presa',
            quantity: 2,
            unitPrice: 18000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 36000,
        deliveryFee: 4000,
        placedAt: now.subtract(const Duration(minutes: 6)),
        customerName: 'Felipe Seis',
        addressLabel: 'Casa',
        landmark: 'Al final del callejón, casa amarilla',
        neighborhood: 'Barrio San Antonio',
        contactPhone: '3148901234',
      ),
      // PREPARANDO — online pickup sin cobrar (el cliente paga
      // transfer al recoger — pickup no acepta efectivo).
      AdminOrder(
        id: 'adm-12',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.pickup,
        status: OrderStatus.preparing,
        statusChangedAt: now.subtract(const Duration(minutes: 3)),
        items: const [
          OrderItem(
            productId: 'p-depredador',
            productSlug: 'depredador',
            name: 'El Depredador',
            quantity: 1,
            unitPrice: 25000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.pending,
        subtotal: 25000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 5)),
        customerName: 'Gabriel Siete',
        contactPhone: '3226789012',
      ),
      // PREPARANDO — online delivery pagado.
      AdminOrder(
        id: 'adm-13',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.delivery,
        status: OrderStatus.preparing,
        statusChangedAt: now.subtract(const Duration(minutes: 1)),
        items: const [
          OrderItem(
            productId: 'p-cachorro',
            productSlug: 'cachorro',
            name: 'El Cachorro',
            quantity: 2,
            unitPrice: 14000,
          ),
          OrderItem(
            productId: 'p-papas',
            productSlug: 'manada-papas',
            name: 'Manada de papas',
            quantity: 1,
            unitPrice: 6000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 34000,
        deliveryFee: 4000,
        placedAt: now.subtract(const Duration(minutes: 7)),
        customerName: 'Héctor Ocho',
        addressLabel: 'Trabajo',
        landmark: 'Bodega de la esquina, preguntar por él',
        neighborhood: 'Barrio El Progreso',
        hasLocationPin: true,
        locationUrl: 'https://maps.app.goo.gl/s5RiFni6LsV4Ptmj9',
        locationLat: 6.2178,
        locationLng: -75.6044,
        contactPhone: '3159012345',
      ),
      // LISTO delivery pagado — "Entregado" (ya salió en camino
      // cobrado).
      AdminOrder(
        id: 'adm-14',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.delivery,
        status: OrderStatus.ready,
        statusChangedAt: now.subtract(const Duration(minutes: 7)),
        items: const [
          OrderItem(
            productId: 'p-carnicero',
            productSlug: 'carnicero',
            name: 'El Carnicero',
            quantity: 1,
            unitPrice: 17000,
          ),
          OrderItem(
            productId: 'p-papas',
            productSlug: 'manada-papas',
            name: 'Manada de papas',
            quantity: 1,
            unitPrice: 10000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 27000,
        deliveryFee: 3000,
        placedAt: now.subtract(const Duration(minutes: 22)),
        customerName: 'Inés Nueve',
        addressLabel: 'Casa',
        landmark: 'Casa rosada junto al parqueadero',
        neighborhood: 'Barrio La Paz',
        contactPhone: '3160123456',
      ),
      // LISTO dine_in YA COBRADO — Mesa 1: "Entregado" libera la
      // mesa (la contracara de Mesa 7, que aún debe).
      AdminOrder(
        id: 'adm-15',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.dineIn,
        status: OrderStatus.ready,
        statusChangedAt: now.subtract(const Duration(minutes: 5)),
        items: const [
          OrderItem(
            productId: 'p-coyote',
            productSlug: 'coyote',
            name: 'El Coyote',
            quantity: 2,
            unitPrice: 18000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 36000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 30)),
        tableLabel: 'Mesa 1',
      ),
      // ENTREGADO dine_in cash — segundo método para el resumen
      // del cierre (efectivo + transferencia en el desglose).
      AdminOrder(
        id: 'adm-16',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.dineIn,
        status: OrderStatus.done,
        statusChangedAt: now.subtract(const Duration(minutes: 8)),
        items: const [
          OrderItem(
            productId: 'p-trampa',
            productSlug: 'trampa',
            name: 'La Trampa',
            quantity: 1,
            unitPrice: 16000,
          ),
          OrderItem(
            productId: 'p-papas',
            productSlug: 'manada-papas',
            name: 'Manada de papas',
            quantity: 1,
            unitPrice: 10000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 26000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(hours: 4)),
        tableLabel: 'Mesa 9',
      ),
      // ENTREGADO online pickup transfer — tercer entregado.
      AdminOrder(
        id: 'adm-17',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.pickup,
        status: OrderStatus.done,
        statusChangedAt: now.subtract(const Duration(minutes: 5)),
        items: const [
          OrderItem(
            productId: 'p-cachorro',
            productSlug: 'cachorro',
            name: 'El Cachorro',
            quantity: 1,
            unitPrice: 14000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 14000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(hours: 2)),
        customerName: 'Jorge Diez',
        contactPhone: '3237890123',
      ),
      // LISTO pickup pagado — Beto ya está en `ready`: su acción
      // de card es "Entregado" (pagado), no el label del paso.
      AdminOrder(
        id: 'adm-3',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.pickup,
        status: OrderStatus.ready,
        statusChangedAt: now.subtract(const Duration(minutes: 3)),
        items: const [
          OrderItem(
            productId: 'p-ave',
            productSlug: 'ave-presa',
            name: 'Ave de Presa',
            quantity: 1,
            unitPrice: 18000,
          ),
          OrderItem(
            productId: 'p-trampa',
            productSlug: 'trampa',
            name: 'La Trampa',
            quantity: 1,
            unitPrice: 16000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 34000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 26)),
        customerName: 'Beto Dos',
        contactPhone: '3248901234',
      ),
      // LISTO dine_in sin cobrar — Mesa 7: la card muestra "Me
      // pagó" (el cobro bloquea el Entregado — caso del §022).
      AdminOrder(
        id: 'adm-8',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.dineIn,
        status: OrderStatus.ready,
        statusChangedAt: now.subtract(const Duration(minutes: 1)),
        items: const [
          OrderItem(
            productId: 'p-carnicero',
            productSlug: 'carnicero',
            name: 'El Carnicero',
            quantity: 1,
            unitPrice: 17000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.pending,
        subtotal: 17000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(minutes: 18)),
        tableLabel: 'Mesa 7',
      ),
      // ENTREGADO sin cerrar — Carla done pagado: vive en `active`
      // hasta el cierre (el mock demuestra el modelo nuevo).
      AdminOrder(
        id: 'adm-5',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.delivery,
        status: OrderStatus.done,
        statusChangedAt: now.subtract(const Duration(minutes: 2)),
        items: const [
          OrderItem(
            productId: 'p-depredador',
            productSlug: 'depredador',
            name: 'El Depredador',
            quantity: 1,
            unitPrice: 25000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 22000,
        deliveryFee: 3000,
        placedAt: now.subtract(const Duration(hours: 3)),
        customerName: 'Carla Tres',
        addressLabel: 'Casa',
        landmark: 'Segunda casa después de la bomba',
        neighborhood: 'Barrio El Prado',
        hasLocationPin: true,
        locationUrl: 'https://maps.app.goo.gl/s5RiFni6LsV4Ptmj9',
        locationLat: 6.2567,
        locationLng: -75.5988,
        contactPhone: '3171234567',
      ),
    ];
  }

  /// Historial mock (§036): solo el cancelado — el done migró a la
  /// cola viva (espera el cierre de caja para archivarse).
  static List<AdminOrder> _defaultHistory() {
    final now = DateTime.now();
    return [
      AdminOrder(
        id: 'adm-6',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.dineIn,
        status: OrderStatus.cancelled,
        items: const [
          OrderItem(
            productId: 'p-cachorro',
            productSlug: 'cachorro',
            name: 'El Cachorro',
            quantity: 2,
            unitPrice: 14000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        // Se canceló antes de cobrar — el backend marca el pago
        // failed al cancelar con cobro pendiente (§019); card y
        // detalle lo suprimen en terminal (deuda fantasma, §034).
        paymentStatus: OrderPaymentStatus.failed,
        subtotal: 28000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(hours: 5)),
        tableLabel: 'Mesa 2',
      ),
      // Cancelado CON MOTIVO — el historial/detalle muestra la
      // razón que el dueño dejó.
      AdminOrder(
        id: 'adm-18',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.delivery,
        status: OrderStatus.cancelled,
        items: const [
          OrderItem(
            productId: 'p-depredador',
            productSlug: 'depredador',
            name: 'El Depredador',
            quantity: 1,
            unitPrice: 25000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.transfer,
        paymentStatus: OrderPaymentStatus.failed,
        subtotal: 21000,
        deliveryFee: 4000,
        placedAt: now.subtract(const Duration(hours: 7)),
        customerName: 'Karla Once',
        addressLabel: 'Casa',
        landmark: 'Frente al colegio',
        neighborhood: 'Barrio Versalles',
        contactPhone: '3182345678',
        cancelReason: 'El cliente no contestó al confirmar',
      ),
      // Cancelado YA COBRADO — caso borde: la plata entró y hay
      // que devolverla; el historial no puede esconderlo.
      AdminOrder(
        id: 'adm-19',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.dineIn,
        status: OrderStatus.cancelled,
        items: const [
          OrderItem(
            productId: 'p-trampa',
            productSlug: 'trampa',
            name: 'La Trampa',
            quantity: 2,
            unitPrice: 16000,
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 32000,
        deliveryFee: 0,
        placedAt: now.subtract(const Duration(hours: 6)),
        tableLabel: 'Mesa 8',
        cancelReason: 'El cliente pidió otro plato en su lugar',
      ),
    ];
  }
}
