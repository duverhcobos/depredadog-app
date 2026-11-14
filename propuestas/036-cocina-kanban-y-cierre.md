# Propuesta: Cocina kanban (5 carriles) + cierre de caja — presentación

El dueño rediseñó su tab: la cola deja de ser lista con filtro
Activos|Historial y se vuelve un **kanban de 5 carriles**
(Pendiente | Confirmado | Preparando | Listo | Entregado) donde cada
pedido avanza visiblemente por su estado. El pedido `done` ya NO sale
de Cocina — queda en el carril Entregado hasta el **cierre de caja**
manual, que lo archiva con resumen del día (total + por método +
# pedidos + cancelados como contexto). El Historial sale del tab:
ícono 🕐 en el header → pantalla aparte (ubicación definitiva se
decide después — hoy pantalla plana provisional).

**Fase: solo presentación** (mocks del cubit — convención
screen-first; el backend §022 se construye DESPUÉS de la aprobación
visual, por la convención "la visual manda el contrato").

Decisiones del dueño ya registradas (encuesta §022): 5 carriles,
cierre vacío permitido, cancelados como contexto en el resumen,
cancelado → historial inmediato, entregado espera al cierre.

Cambios de modelo:

1. `OrderStatus` (espejo backend) gana `ready` — se inserta entre
   `preparing` y `done`. `done` deja de ser terminal-invisible: el
   `isTerminal` sigue marcando "sin más acciones" pero el done vive
   en `active` hasta el cierre (solo `cancelled` cruza a `history`
   de una).
2. `AdminOrder` gana `serviceType` — nuevo enum
   `AdminServiceType {pickup, delivery, dineIn}` (espejo completo
   del backend; el `OrderServiceType` del cliente se queda con
   pickup/delivery — el cliente nunca dine_in). El label del paso
   `ready` cambia por canal: delivery "Va en camino", dineIn
   "Servir", pickup "Listo p/recoger".
3. Matriz de acciones nueva (card + detalle comparten
   `adminOrderNextAction`):
   - `received` → **Confirmar**
   - `confirmed` → **Preparar**
   - `preparing` → **etiqueta ready por serviceType**
   - `ready` + pago pendiente/fallido → **Me pagó** (el done exige
     cobro — el 409 del backend se adelanta)
   - `ready` + pagado → **Entregado**
   - `done`/`cancelled` → sin acción
   "Me pagó" desaparece de cards en estados tempranos — en mesa se
   sirve antes de cobrar; el cobro manual sigue en el detalle y
   vuelve a ser acción de card solo cuando bloquea Entregado.
4. `AdminQueueCubit` gana `closeDay()` mock: los `done` del activo
   pasan a history (estampados por el cierre) y devuelve el resumen
   de la jornada calculado de los mismos mocks — tras cerrar, el
   carril Entregado queda vacío de verdad.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/orders/domain/entities/customer_order.dart` | `OrderStatus` +`ready` |
| `lib/features/admin/domain/entities/admin_order.dart` | +`AdminServiceType` + campo `serviceType` |
| `lib/features/admin/domain/entities/admin_day_close.dart` | nuevo — entidad resumen del cierre |
| `lib/features/admin/presentation/cubit/admin_queue_state.dart` | quita filtro; getters de carril |
| `lib/features/admin/presentation/cubit/admin_queue_cubit.dart` | matriz 5 estados + `closeDay()` + mocks |
| `lib/features/admin/presentation/widgets/admin_order_action.dart` | matriz + labels por canal |
| `lib/features/admin/presentation/widgets/admin_order_chips.dart` | chips `preparing`/`ready` |
| `lib/features/admin/presentation/widgets/admin_lane_strip.dart` | nuevo — strip de carriles |
| `lib/features/admin/presentation/widgets/admin_queue_lane.dart` | nuevo — página carril |
| `lib/features/admin/presentation/widgets/admin_queue_filter.dart` | **eliminar** (el segmented sale) |
| `lib/features/admin/presentation/screens/admin_queue_screen.dart` | kanban + acciones header |
| `lib/features/admin/presentation/screens/admin_day_close_screen.dart` | nuevo — preview/cierre |
| `lib/features/admin/presentation/screens/admin_history_screen.dart` | nuevo — historial provisional |
| `lib/core/routes/app_router.dart` | +`/admin/day-close` + `/admin/history` ANTES de `:id` |
| `lib/l10n/app_es.arb` | claves nuevas + `flutter gen-l10n` |
| `test/...admin...` | cubit (matriz, carriles, cierre), action (labels/canal), screens, router |
| `Design/design-system.yaml` | bump + spec kanban/cierre tras aprobación |

---

## 1. customer_order.dart (archivo existente — actualización)

**Ruta:** `lib/features/orders/domain/entities/customer_order.dart`

**Antes:**
```dart
enum OrderStatus { received, confirmed, preparing, done, cancelled }
```

**Después:**
```dart
enum OrderStatus { received, confirmed, preparing, ready, done, cancelled }
```

(actualizar el doc del enum: `ready` es el paso "listo para
entrega/en camino/servido" del backend §022 — la app lo etiqueta por
canal; `done` = entregado. Verificar otros switch sobre OrderStatus
— chips de Pedidos del cliente pueden necesitar el caso `ready`
aunque el cliente aún no lo reciba: default defensivo.)

## 2. admin_order.dart (archivo existente — actualización)

**Ruta:** `lib/features/admin/domain/entities/admin_order.dart`

**Antes:**
```dart
enum AdminPaymentMethod { cash, transfer }
```

**Después:**
```dart
enum AdminPaymentMethod { cash, transfer }

/// Tipo de servicio del pedido (espejo `order_service_type` —
/// incluye dine_in que el enum del cliente no tiene porque el
/// cliente nunca pide a mesa; solo lo crea el dueño). Define el
/// label del paso `ready` en la matriz de acciones.
enum AdminServiceType { pickup, delivery, dineIn }
```

Y en `AdminOrder`:

**Antes:**
```dart
    required this.channel,
    required this.status,
    required this.items,
    required this.paymentMethod,
```
```dart
  AdminOrder copyWith({
    OrderStatus? status,
    OrderPaymentStatus? paymentStatus,
    String? cancelReason,
  }) => AdminOrder(
    id: id,
    channel: channel,
    status: status ?? this.status,
    items: items,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    total: total,
    placedAt: placedAt,
    tableLabel: tableLabel,
    customerName: customerName,
    cancelReason: cancelReason ?? this.cancelReason,
  );
```

**Después:**
```dart
    required this.channel,
    required this.serviceType,
    required this.status,
    required this.items,
    required this.paymentMethod,
```
```dart
  /// Servicio (espejo `service_type` del backend §022) — define la
  /// etiqueta del paso `ready`: delivery "Va en camino", dineIn
  /// "Servir", pickup "Listo p/recoger".
  final AdminServiceType serviceType;
```
```dart
  AdminOrder copyWith({
    OrderStatus? status,
    OrderPaymentStatus? paymentStatus,
    String? cancelReason,
  }) => AdminOrder(
    id: id,
    channel: channel,
    serviceType: serviceType,
    status: status ?? this.status,
    items: items,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    total: total,
    placedAt: placedAt,
    tableLabel: tableLabel,
    customerName: customerName,
    cancelReason: cancelReason ?? this.cancelReason,
  );
```

(+ `serviceType` en `props`)

## 3. admin_day_close.dart (archivo nuevo)

**Ruta:** `lib/features/admin/domain/entities/admin_day_close.dart`

```dart
import 'package:equatable/equatable.dart';

/// Resumen del cierre de caja (espejo DayClosePreview/DayClose del
/// backend §022 — solo presentación, lo calculan los mocks):
/// cuántos pedidos entregados se archivan, el total vendido, el
/// desglose por método y los cancelados del periodo como contexto.
class AdminDayClose extends Equatable {
  const AdminDayClose({
    required this.orderCount,
    required this.totalAmount,
    required this.byMethod,
    required this.cancelledCount,
    required this.cancelledAmount,
  });

  final int orderCount;
  final int totalAmount;
  final List<AdminDayCloseMethod> byMethod;
  final int cancelledCount;
  final int cancelledAmount;

  bool get isEmpty => orderCount == 0 && cancelledCount == 0;

  @override
  List<Object?> get props => [
    orderCount,
    totalAmount,
    byMethod,
    cancelledCount,
    cancelledAmount,
  ];
}

/// Una pierna del desglose por método ("efectivo $120.000 × 5").
class AdminDayCloseMethod extends Equatable {
  const AdminDayCloseMethod({
    required this.method,
    required this.count,
    required this.amount,
  });

  /// Espejo `payment_method` del backend — cash/transfer/(gateway
  /// llega en integración).
  final String method;
  final int count;
  final int amount;

  @override
  List<Object?> get props => [method, count, amount];
}
```

## 4. admin_queue_state.dart (archivo existente — reescritura)

**Ruta:** `lib/features/admin/presentation/cubit/admin_queue_state.dart`

Sale el `AdminQueueFilter` (el segmented muere con el kanban) y el
estado gana los getters de carril. `history` se conserva: resuelve
detalle de cancelados y alimenta la pantalla provisional de
historial.

```dart
import 'package:equatable/equatable.dart';

import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_order.dart';
import '../../domain/entities/admin_day_close.dart';

/// Estado del tab Cocina kanban (§036, solo presentación — mocks):
/// una sola bandeja `active` (en curso + entregados sin cerrar) de
/// la que se derivan los 5 carriles; `history` guarda los archivados
/// por cierre + cancelados; `dayClose` es el preview del cierre que
/// ve la pantalla /admin/day-close.
class AdminQueueState extends Equatable {
  const AdminQueueState({
    this.active = const [],
    this.history = const [],
    this.dataLoading = true,
    this.failed = false,
    this.busyOrderIds = const {},
    this.dayClose,
    this.dayCloseBusy = false,
  });

  /// Cola viva: en curso (received→ready) + done SIN cerrar — el
  /// entregado espera al cierre de caja para archivarse.
  final List<AdminOrder> active;

  /// Archivados (done cerrados + cancelados), más reciente primero.
  final List<AdminOrder> history;

  final bool dataLoading;
  final bool failed;
  final Set<String> busyOrderIds;

  /// Preview del cierre calculado en mocks — null hasta que la
  /// pantalla /admin/day-close lo pida.
  final AdminDayClose? dayClose;

  /// El cierre mock está en vuelo — el CTA de confirmar muestra
  /// spinner (convención checkout).
  final bool dayCloseBusy;

  /// Carriles del kanban en orden fijo — done va último (es el
  /// "carril entregados" que espera el cierre).
  static const laneStatuses = [
    OrderStatus.received,
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.done,
  ];

  /// Pedidos del carril en FIFO de cocina (más viejo arriba — el
  /// que más espera se atiende primero).
  List<AdminOrder> laneOrders(OrderStatus status) => [
    for (final o in active)
      if (o.status == status) o,
  ]..sort((a, b) => a.placedAt.compareTo(b.placedAt));

  /// Entregados esperando cierre — alimenta el contador del botón.
  int get deliveredCount =>
      active.where((o) => o.status == OrderStatus.done).length;

  bool get isEmpty => active.isEmpty && history.isEmpty;

  AdminOrder? orderById(String id) {
    for (final list in [active, history]) {
      for (final order in list) {
        if (order.id == id) return order;
      }
    }
    return null;
  }

  AdminQueueState copyWith({
    List<AdminOrder>? active,
    List<AdminOrder>? history,
    bool? dataLoading,
    bool? failed,
    Set<String>? busyOrderIds,
    AdminDayClose? Function()? dayClose,
    bool? dayCloseBusy,
  }) => AdminQueueState(
    active: active ?? this.active,
    history: history ?? this.history,
    dataLoading: dataLoading ?? this.dataLoading,
    failed: failed ?? this.failed,
    busyOrderIds: busyOrderIds ?? this.busyOrderIds,
    dayClose: dayClose != null ? dayClose() : this.dayClose,
    dayCloseBusy: dayCloseBusy ?? this.dayCloseBusy,
  );

  @override
  List<Object?> get props => [
    active,
    history,
    dataLoading,
    failed,
    busyOrderIds,
    dayClose,
    dayCloseBusy,
  ];
}
```

## 5. admin_queue_cubit.dart (archivo existente — actualización)

**Ruta:** `lib/features/admin/presentation/cubit/admin_queue_cubit.dart`

**Antes (avance de 2 pasos):**
```dart
  /// Avanza un paso en la matriz del contrato (§019): pending →
  /// confirmed, confirmed/preparing → done; done/cancelled → no-op.
  Future<void> advanceOrder(String id) => _mutateOrder(id, (order) {
    if (order.isTerminal) return null;
    final next = switch (order.status) {
      OrderStatus.received => OrderStatus.confirmed,
      OrderStatus.confirmed || OrderStatus.preparing => OrderStatus.done,
      OrderStatus.done || OrderStatus.cancelled => order.status,
    };
    return order.copyWith(status: next);
  });
```

**Después (matriz de 5 pasos del §022):**
```dart
  /// Avanza un paso en la matriz del §022: received→confirmed→
  /// preparing→ready→done; terminal → no-op. En integración =
  /// PATCH /admin/orders/:id/status {to}. El invariante "done exige
  /// pago cobrado" lo adelanta la UI: el paso a done solo aparece
  /// con paymentStatus == paid.
  Future<void> advanceOrder(String id) => _mutateOrder(id, (order) {
    if (order.isTerminal) return null;
    final next = switch (order.status) {
      OrderStatus.received => OrderStatus.confirmed,
      OrderStatus.confirmed => OrderStatus.preparing,
      OrderStatus.preparing => OrderStatus.ready,
      OrderStatus.ready => OrderStatus.done,
      OrderStatus.done || OrderStatus.cancelled => order.status,
    };
    return order.copyWith(status: next);
  });
```

**Antes (swap a history para cualquier terminal):**
```dart
      if (updated.isTerminal) {
        // Swap de bucket — el terminal sale de la cola y entra al
        // frente del historial (misma regla del use-case real;
        // `visible` ya ordena cada bandeja).
        emit(
          state.copyWith(
            active: state.active.where((o) => o.id != id).toList(),
            history: [updated, ...state.history.where((o) => o.id != id)],
            busyOrderIds: busy,
          ),
        );
      } else {
```

**Después (solo `cancelled` sale — `done` se queda en el carril
Entregado hasta el cierre):**
```dart
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
```

**Nuevos métodos (al final, antes de `_syncMocks`):**
```dart
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
```

**Mocks — redistribución por carril** (mismo estilo; cada orden gana
`serviceType:`):

```dart
  static List<AdminOrder> _defaultActive() {
    final now = DateTime.now();
    return [
      // PENDIENTE — online delivery, transfer pendiente.
      AdminOrder(
        id: 'adm-1',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.delivery,
        status: OrderStatus.received,
        // ...mismos ítems Ana Uno $56.000 transfer pending...
      ),
      // CONFIRMADO — dine_in Mesa 3 cash pendiente.
      AdminOrder(
        id: 'adm-2',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.dineIn,
        status: OrderStatus.confirmed,
        // ...mismos ítems Mesa 3 $14.000 cash pending...
      ),
      // CONFIRMADO — presencial mostrador pagado (adm-4 pasa de
      // received a confirmed: el backend §019 crea presenciales ya
      // confirmados — un 'received' presencial es contrato viejo).
      AdminOrder(
        id: 'adm-4',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.pickup,
        status: OrderStatus.confirmed,
        // ...mismos ítems $36.000 cash paid...
      ),
      // PREPARANDO — Mesa 5 (la orden grande) dine_in cash paid.
      AdminOrder(
        id: 'adm-7',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.dineIn,
        status: OrderStatus.preparing,
        // ...los 7 ítems $118.000 cash paid...
      ),
      // LISTO pickup — Beto pickup pagado → botón "Listo p/recoger"
      // no: ya ESTÁ ready → su acción es "Entregado" (pagado).
      AdminOrder(
        id: 'adm-3',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.pickup,
        status: OrderStatus.ready,
        // ...mismos ítems Beto $34.000 transfer paid...
      ),
      // LISTO dine_in sin cobrar — Mesa 7: la card muestra "Me pagó"
      // (el cobro bloquea el Entregado — caso del §022).
      AdminOrder(
        id: 'adm-8',
        channel: AdminOrderChannel.presencial,
        serviceType: AdminServiceType.dineIn,
        status: OrderStatus.ready,
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
        total: 17000,
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
        // ...mismos ítems Carla $25.000 transfer paid...
      ),
    ];
  }
```

`_defaultHistory` queda solo con el cancelado Mesa 2 (Carla done
emigra al activo).

## 6. admin_order_action.dart (archivo existente — actualización)

**Ruta:** `lib/features/admin/presentation/widgets/admin_order_action.dart`

**Antes:**
```dart
enum AdminOrderAction { confirm, markPaid, markDone }

AdminOrderAction? adminOrderNextAction(AdminOrder order) {
  if (order.isTerminal) return null;
  if (order.status == OrderStatus.received) return AdminOrderAction.confirm;
  if (order.paymentStatus != OrderPaymentStatus.paid) {
    return AdminOrderAction.markPaid;
  }
  return AdminOrderAction.markDone;
}
```

**Después:**
```dart
/// La siguiente acción real del pedido en la matriz de 5 pasos
/// (§036): received→confirmed→preparing→ready→done + el cobro como
/// puerta solo en `ready` (el done del backend exige PAID — un
/// cobro sin saldar vuelve "Me pagó" la acción porque bloquea el
/// Entregado). En estados tempranos el cobro no es la acción de la
/// card: en mesa se sirve antes de cobrar (vive en el detalle).
/// Terminal = sin acción.
enum AdminOrderAction { confirm, prepare, markReady, markPaid, markDone }

AdminOrderAction? adminOrderNextAction(AdminOrder order) {
  if (order.isTerminal) return null;
  if (order.status == OrderStatus.ready &&
      order.paymentStatus != OrderPaymentStatus.paid) {
    return AdminOrderAction.markPaid;
  }
  return switch (order.status) {
    OrderStatus.received => AdminOrderAction.confirm,
    OrderStatus.confirmed => AdminOrderAction.prepare,
    OrderStatus.preparing => AdminOrderAction.markReady,
    OrderStatus.ready => AdminOrderAction.markDone,
    OrderStatus.done || OrderStatus.cancelled => null,
  };
}
```

**Label — depende de serviceType en `markReady`:**
```dart
String adminOrderActionLabel(
  AppLocalizations l10n,
  AdminOrderAction action, {
  AdminServiceType? serviceType,
}) => switch (action) {
  AdminOrderAction.confirm => l10n.adminActionConfirm,
  AdminOrderAction.prepare => l10n.adminActionPrepare,
  AdminOrderAction.markReady => switch (serviceType) {
    AdminServiceType.delivery => l10n.adminActionOnTheWay,
    AdminServiceType.dineIn => l10n.adminActionServe,
    _ => l10n.adminActionReadyPickup,
  },
  AdminOrderAction.markPaid => l10n.adminActionPaid,
  AdminOrderAction.markDone => l10n.adminActionDeliver,
};
```

(y `runAdminOrderAction`: `prepare`/`markReady`/`markDone` →
`cubit.advanceOrder`; toasts nuevos por acción; el button pasa
`order.serviceType` al label. El detalle (`admin_order_detail_actions`)
reusa el mismo resolver — el caso `ready`+sin-pago muestra "Me pagó"
primario + "Entregado" deshabilitado con la pista, igual que hoy.)

## 7. admin_order_chips.dart (archivo existente — actualización)

Agregar los casos `preparing` y `ready` al chip de estado (labels ya
existen: `orderStatusPreparing` "En la plancha", `orderStatusReady`
"Listo") — mismos colores de semáforo que la familia de chips
(Pendiente sólido conserva su prioridad §034b; el `done` usa
"Entregado" `orderStatusDelivered`).

## 8. admin_lane_strip.dart (archivo nuevo)

**Ruta:** `lib/features/admin/presentation/widgets/admin_lane_strip.dart`

Strip fijo de carriles bajo el header — el tablero de un vistazo:
5 chips (label + contador), el activo se resalta; tap → salta el
PageController al carril. Scroll horizontal defensivo por si el
ancho no alcanza.

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../orders/domain/entities/customer_order.dart';
import '../cubit/admin_queue_state.dart';

/// Strip de carriles del kanban (§036): 5 chips label+count que son
/// también el resumen del tablero ("3 preparando" se ve sin entrar
/// al carril). El chip activo se pinta con el color del carril —
/// semáforo consistente con los chips de estado de la card.
class AdminLaneStrip extends StatelessWidget {
  const AdminLaneStrip({
    required this.state,
    required this.index,
    required this.onJump,
    super.key,
  });

  final AdminQueueState state;
  final int index;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final lanes = AdminQueueState.laneStatuses;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < lanes.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _LaneChip(
              label: _laneLabel(l10n, lanes[i]),
              count: state.laneOrders(lanes[i]).length,
              selected: i == index,
              onTap: () => onJump(i),
            ),
          ],
        ],
      ),
    );
  }

  static String _laneLabel(AppLocalizations l10n, OrderStatus s) =>
      switch (s) {
        OrderStatus.received => l10n.orderStatusReceived,
        OrderStatus.confirmed => l10n.orderStatusConfirmed,
        OrderStatus.preparing => l10n.orderStatusPreparing,
        OrderStatus.ready => l10n.orderStatusReady,
        OrderStatus.done => l10n.orderStatusDelivered,
        OrderStatus.cancelled => '',
      };
}

class _LaneChip extends StatelessWidget {
  const _LaneChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.16)
              : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: text.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? colors.primary : colors.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected ? colors.onPrimary : colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 9. admin_queue_lane.dart (archivo nuevo)

**Ruta:** `lib/features/admin/presentation/widgets/admin_queue_lane.dart`

La página de un carril dentro del PageView: sus cards en scroll
vertical FIFO o el vacío compacto del carril. `RefreshIndicator` no
va aquí — el pull-to-refresh vive a nivel tablero (mismo gesto de
siempre).

```dart
import 'package:flutter/material.dart';

import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_order.dart';
import '../cubit/admin_queue_state.dart';
import 'admin_order_card.dart';

/// Una página-carril del kanban (§036): la lista vertical del estado
/// en FIFO. El carril vacío muestra un empty compacto — en kanban el
/// carril existe aunque no tenga pedidos (la ausencia también es
/// información: "nada en la plancha").
class AdminQueueLane extends StatelessWidget {
  const AdminQueueLane({
    required this.status,
    required this.state,
    super.key,
  });

  final OrderStatus status;
  final AdminQueueState state;

  @override
  Widget build(BuildContext context) {
    final orders = state.laneOrders(status);
    if (orders.isEmpty) {
      final colors = Theme.of(context).colorScheme;
      final text = Theme.of(context).textTheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '—',
            style: text.titleMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final order in orders)
          AdminOrderCard(
            order: order,
            busy: state.busyOrderIds.contains(order.id),
          ),
      ],
    );
  }
}
```

## 10. admin_queue_screen.dart (archivo existente — reescritura mayor)

**Ruta:** `lib/features/admin/presentation/screens/admin_queue_screen.dart`

Cambios estructurales (el resto del archivo — `_QueueError`,
`_QueueErrorRow`, `_QueueEmpty` — se conserva; el vacío global solo
aplica cuando TODOS los carriles están vacíos):

- Sale `AdminQueueSegmentedFilter` y el `ListView` de una sola cola.
- **Header fijo** (no scrollea — rompemos `scrolling_title_tab` a
  propósito: en un tablero el cromo debe quedar quieto, decisión
  aprobada por el dueño): fila con **botón `FilledButton.tonalIcon`
  "Cerrar caja" AL FRENTE** (leading — decisión del dueño: "al
  frente del título de cocina") con el contador de entregados →
  `context.push('/admin/day-close')`, después el título "Cocina",
  y al trailing el ícono historial 🕐 (`Icons.history_rounded` →
  `context.push('/admin/history')`).
- `AdminLaneStrip` bajo el header (fijo).
- `PageView` de 5 `AdminQueueLane` — un carril a la vez, swipe o tap
  del chip para saltar. `PageController` con `viewportFraction: 1`.
- `RefreshIndicator` envuelve el PageView (cada lane ya es ListView
  AlwaysScrollable — el pull funciona).
- El FAB "Nueva orden" queda igual.

**Antes:**
```dart
                      children: [
                        const _QueueTitle(),
                        AdminQueueSegmentedFilter(
                          selected: state.filter,
                          onChanged: (filter) =>
                              context.read<AdminQueueCubit>().setFilter(filter),
                        ),
```

**Después (estructura del body — el StatefulWidget maneja el
PageController):**
```dart
// AdminQueueScreen pasa a StatefulWidget por el PageController.
Column(
  children: [
    _QueueHeader(
      deliveredCount: state.deliveredCount,
      onHistory: () => context.push('/admin/history'),
      onCloseDay: () => context.push('/admin/day-close'),
    ),
    AdminLaneStrip(
      state: state,
      index: _pageIndex,
      onJump: (i) => _pageController.animateToPage(
        i,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    ),
    Expanded(
      child: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _pageIndex = i),
        children: [
          for (final s in AdminQueueState.laneStatuses)
            AdminQueueLane(status: s, state: state),
        ],
      ),
    ),
  ],
)
```

`_QueueHeader` (nuevo, privado del archivo): franja-aware —
title mostaza + acciones en la zona negra:

```dart
class _QueueHeader extends StatelessWidget {
  const _QueueHeader({
    required this.deliveredCount,
    required this.onHistory,
    required this.onCloseDay,
  });

  final int deliveredCount;
  final VoidCallback onHistory;
  final VoidCallback onCloseDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          // Cierre AL FRENTE del título — decisión del dueño: la
          // acción más importante del dueño es lo primero que lee.
          FilledButton.tonalIcon(
            onPressed: onCloseDay,
            icon: const Icon(Icons.point_of_sale_rounded, size: 18),
            label: Text(
              deliveredCount > 0
                  ? '${l10n.adminCloseDay} · $deliveredCount'
                  : l10n.adminCloseDay,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.adminQueueTitle,
              style: text.headlineSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: onHistory,
            icon: const Icon(Icons.history_rounded),
            tooltip: l10n.adminHistoryTitle,
          ),
        ],
      ),
    );
  }
}
```

(El header queda dentro de la zona negra — la franja SignatureStrip
sigue igual; verificar márgenes con `blackZoneMargin` al implementar.)

## 11. admin_day_close_screen.dart (archivo nuevo)

**Ruta:** `lib/features/admin/presentation/screens/admin_day_close_screen.dart`

Ruta hija de `/admin` (`/admin/day-close` — declarada ANTES de `:id`
en el router o el segmento se lo traga el detalle). Pantalla empujada
(slideUp como el detalle): preview del cierre → confirmar → éxito.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/admin_day_close.dart';
import '../cubit/admin_queue_cubit.dart';
import '../cubit/admin_queue_state.dart';

/// Cierre de caja del día (§036 — presentación, mocks del cubit):
/// preview del resumen (entregados por archivar, total, por método,
/// cancelados del periodo) → "Confirmar cierre" ejecuta → estado de
/// éxito con check + el resumen cerrado + "Listo" que regresa.
/// El cierre vacío está permitido (decisión del dueño) — con cero
/// entregados la pantalla muestra el resumen en ceros con su nota.
class AdminDayCloseScreen extends StatefulWidget {
  const AdminDayCloseScreen({super.key});

  @override
  State<AdminDayCloseScreen> createState() => _AdminDayCloseScreenState();
}

class _AdminDayCloseScreenState extends State<AdminDayCloseScreen> {
  AdminDayClose? _result;

  @override
  void initState() {
    super.initState();
    // Preview al entrar (GET /admin/day-close en integración).
    context.read<AdminQueueCubit>().loadDayClosePreview();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return BlocBuilder<AdminQueueCubit, AdminQueueState>(
      builder: (context, state) {
        final summary = _result ?? state.dayClose;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.adminDayCloseTitle)),
          body: summary == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _TotalHero(amount: summary.totalAmount),
                    const SizedBox(height: 16),
                    _SummaryRows(summary: summary),
                    if (summary.cancelledCount > 0) ...[
                      const SizedBox(height: 8),
                      _CancelledRow(summary: summary),
                    ],
                  ],
                ),
          bottomNavigationBar: _result == null
              ? SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: IgnorePointer(
                      ignoring: state.dayCloseBusy,
                      child: FilledButton(
                        onPressed: () async {
                          final result = await context
                              .read<AdminQueueCubit>()
                              .closeDay();
                          if (!context.mounted || result == null) return;
                          setState(() => _result = result);
                        },
                        child: state.dayCloseBusy
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.onPrimary,
                                ),
                              )
                            : Text(l10n.adminDayCloseConfirm),
                      ),
                    ),
                  ),
                )
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton.tonal(
                      onPressed: () => context.pop(),
                      child: Text(l10n.adminDayCloseDone),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
```

Widgets privados del mismo archivo:

```dart
/// Hero del total — el número que el dueño quiere ver primero.
class _TotalHero extends StatelessWidget {
  const _TotalHero({required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          l10n.adminDayCloseTotal,
          style: text.labelLarge?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 0).format(amount)}',
          style: text.displaySmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

/// Filas del resumen: pedidos + desglose por método.
class _SummaryRows extends StatelessWidget {
  const _SummaryRows({required this.summary});
  final AdminDayClose summary;
  // "12 pedidos entregados" + por método: "Efectivo — 5 · $120.000",
  // "Transferencia — 7 · $220.000". Mismo formato money del proyecto.
}

/// Contexto del dueño: "2 cancelados · $42.000" — no suma al total.
class _CancelledRow extends StatelessWidget {
  const _CancelledRow({required this.summary});
  final AdminDayClose summary;
}
```

(El éxito se ve como el mismo resumen pero tras la línea del
check/toast — simplest: tras `closeDay` el `_result` fija el
snapshot y un `AppToast.success` marca el cierre. Detalle fino al
implementar.)

## 12. admin_history_screen.dart (archivo nuevo)

**Ruta:** `lib/features/admin/presentation/screens/admin_history_screen.dart`

Historial provisional — pantalla empujada con el bucket `history`
existente (cards sin acción). La ubicación/diseño definitivo se
decide después (dueño: "historial lo resolvemos después dónde va").

```dart
/// Historial provisional (§036): lista plana de archivados con las
/// mismas cards en modo solo-lectura (sin acción en terminal).
/// Acceso: ícono 🕐 del header de Cocina → /admin/history.
class AdminHistoryScreen extends StatelessWidget {
  const AdminHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminHistoryTitle)),
      body: BlocBuilder<AdminQueueCubit, AdminQueueState>(
        builder: (context, state) {
          final orders = [...state.history]
            ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
          if (orders.isEmpty) {
            // Empty "Historial vacío" — textos ya existentes.
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final order in orders)
                AdminOrderCard(order: order, busy: false),
            ],
          );
        },
      ),
    );
  }
}
```

## 13. app_router.dart (archivo existente — actualización)

**Ruta:** `lib/core/routes/app_router.dart`

**Antes:**
```dart
                routes: [
                  // Detalle del pedido (§035 — mismo patrón que la
                  // hija /orders/:id): extra = AdminOrder; sin extra
                  // válido (deep link, estado restaurado) → /admin.
                  GoRoute(
                    path: ':id',
```

**Después:**
```dart
                routes: [
                  // ORDEN IMPORTA: las rutas literales van ANTES de
                  // ':id' o el segmento las traga como parámetro.
                  GoRoute(
                    path: 'day-close',
                    pageBuilder: (context, state) =>
                        CustomTransitions.slideUp(
                      state,
                      BlocProvider.value(
                        value: locator<AdminQueueCubit>(),
                        child: const AdminDayCloseScreen(),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'history',
                    pageBuilder: (context, state) =>
                        CustomTransitions.slideUp(
                      state,
                      BlocProvider.value(
                        value: locator<AdminQueueCubit>(),
                        child: const AdminHistoryScreen(),
                      ),
                    ),
                  ),
                  // Detalle del pedido (§035 — mismo patrón que la
                  // hija /orders/:id): extra = AdminOrder; sin extra
                  // válido (deep link, estado restaurado) → /admin.
                  GoRoute(
                    path: ':id',
```

## 14. app_es.arb (archivo existente — actualización)

Claves nuevas (regenerar con `flutter gen-l10n`):

```json
"adminActionPrepare": "Preparar",
"adminActionOnTheWay": "Va en camino",
"adminActionServe": "Servir",
"adminActionReadyPickup": "Listo p/recoger",
"adminActionDeliver": "Entregado",
"adminCloseDay": "Cerrar caja",
"adminHistoryTitle": "Historial",
"adminDayCloseTitle": "Cierre de caja",
"adminDayCloseTotal": "Vendido hoy",
"adminDayCloseConfirm": "Confirmar cierre",
"adminDayCloseDone": "Listo",
"adminDayCloseOrders": "{count} pedidos entregados",
"adminDayCloseCancelled": "{count} cancelados · ${amount}",
"adminDayCloseEmpty": "Cierre del día — sin pedidos entregados. El registro queda como bitácora.",
"adminToastOrderPreparing": "Pedido a la plancha",
"adminToastOrderReady": "Pedido listo",
"adminToastDayClosed": "Día cerrado — {total}",
"adminLaneEmpty": "Sin pedidos",
```

(las de estado `orderStatus*` ya existen; los placeholders icu
siguiendo la convención del arb. Verificar nombres finales contra
las claves existentes.)

## 15. Tests

- `admin_queue_cubit_test.dart` — nueva matriz (received→confirmed→
  preparing→ready→done), ready+unpaid → "Me pagó" gate, done queda
  en `active` (no cruza a history), `closeDay` archiva done +
  resumen correcto, cierre vacío.
- `admin_order_action_test.dart` — labels por serviceType en
  markReady (delivery/dineIn/pickup), matriz ready+pagado →
  Entregado.
- `admin_queue_screen_test.dart` — strip de 5 chips con contadores,
  swipe entre carriles, vacío global, contador del botón cierre.
- `admin_day_close_screen_test.dart` — preview render, confirmar →
  busy → resultado fijo + pop.
- Router test — `day-close`/`history` resuelven antes que `:id`.

## 16. design-system.yaml (tras aprobación)

Bump + spec `admin_kanban` (lane strip, página carril, semáforo de
carriles) y `admin_day_close` (hero total + resumen) — post gate
visual.

---

---

## Ajustes post-crítica estética (aplicados tras implementación)

1. **Strip acotado a la zona negra** — padding left del scroll de
   chips = `ancho × kSignatureStripFraction` (el chip activo
   primario-sobre-mostaza desaparecía; §034c aplica a TODO el
   tablero). `AdminLaneStrip` es StatefulWidget con `ensureVisible`
   al chip activo cuando cambia el `index` — el tablero nunca
   pierde el indicador de posición.
2. **Empty de carril** acotado a zona negra + α0.3→0.4 (susurro
   decidido, no artefacto gris).
3. **CTA de éxito sólido** — "Listo" tras cerrar es FilledButton
   (único gesto disponible; tonal se leía deshabilitado).
4. **Lenguaje firma en auxiliares** (DIRECCIÓN aprobado por el
   dueño): `/admin/day-close` y `/admin/history` llevan el mismo
   patrón del detalle §035 — `SignatureStrip` + flecha `onPrimary`
   sobre mostaza + título naciente en la zona negra; nada de AppBar
   M3 genérico. El footer del cierre queda fijo opaco (patrón del
   detalle).
5. Test del strip: `ensureVisible` antes del tap — en superficie
   800×600 'Listo' nace fuera del viewport (mismo comportamiento
   real del widget).
6. **Correcciones revisor-ui**: padding de zona negra FUERA del
   scrollable del strip (los chips ya no se deslizan bajo la franja
   al scrollear — el viewport mismo es la zona negra); footer del
   cierre con `SizedBox(width: infinity)` (era una caja flotante
   sobre la franja); chips con `minHeight: 44` +
   `Semantics(selected, inMutuallyExclusiveGroup)`; strip oculto en
   vacío global/error sin datos.
7. **Feedback del dueño (header)**: "Caja" compacto con badge de
   notificación por contador (era "Cerrar caja · N" grande); el
   título COCINA nace pegado al filo de la franja (slot del ícono
   = `ancho × 0.398` — la calibración `widthFactor 0.602` del
   título naciente); FAB pasa a ícono solo (`adminCloseDay` →
   `adminCloseDayShort`).
8. **Feedback del dueño (cards)**: el chip de la card muestra el
   SERVICIO (Domicilio/Recogida/Mesa — decisión operativa), no el
   canal; el chip de ESTADO sale de la card en carril (el carril
   ya lo dice) y se conserva solo en historial + detalle; el canal
   vive en el detalle (`[Online|Presencial] [Servicio] [Estado]`).
9. **Terminología neutral**: "Registrar pago" (era "Me pagó"),
   pista "Registra el pago primero".
10. **Puerta de confirmación §036** (regla del dueño): la recogida
    sin cobrar no confirma — la acción pasa a "Registrar pago" y el
    Confirmar queda visible deshabilitado con pista. La puerta hoy
    solo dispara en **presencial** (mostrador/teléfono): la
    **recogida ONLINE solo acepta Nequi dentro de la app** — un
    pedido online de recogida pagable en efectivo/transfer deja
    producir para un cliente que nunca llega. El resto del received
    confirma libre (mesa se cobra al final, delivery lo cobra el
    dueño en la puerta o es contraentrega). `ready→done` sigue
    exigiendo pago.
11. **Nequi congelado** (regla del dueño): `AdminPaymentMethod.nequi`
    — cobro dentro de la app que confirma el webhook, nadie lo
    adelanta. Pending/failed sin confirmar → la card muestra rótulo
    ("Esperando confirmación de Nequi…" / "Nequi rechazó el pago —
    cancela el pedido") SIN botones; el detalle no muestra avance
    ni cobro (failed deja solo "Cancelar pedido"). Guardias en el
    cubit: `advanceOrder` y `markPaid` son no-op sobre Nequi sin
    pagar. Nequi ya pagado fluye normal (Wanda, Confirmado).
    El desglose del cierre etiqueta 'nequi'.
12. **Nacimiento por canal** (decisión del dueño, gate visual):
    el presencial lo crea el dueño — **dineIn y delivery nacen en
    `confirmed`** (Óscar, Mesa 4, Mesa 6 nunca pisan Pendiente).
    La recogida presencial nace en `received` SIEMPRE — aunque
    esté paga — porque el cliente tarda un momento en pagar en el
    mostrador/transferencia, y la bandeja es el aviso. Los online
    siempre nacen `received`.
13. **"Registrar pago" = cobra Y avanza** (decisión del dueño):
    el cobro era el único bloqueo — un toque lo resuelve todo.
    Recogida presencial sin cobrar → `confirmed` directo; pedido
    `ready` sin cobrar → `done` directo (mesa que paga y se va,
    delivery cobrado en la puerta). En mesa el cobro ocurre "cuando
    la gente se va a ir" — la comida sale primero, el pedido espera
    en Listo hasta la cuenta.
14. **El canal vuelve a la card como susurro** (decisión del
    dueño: "en la parte superior derecha colocar si es online o
    presencial") — `AdminChannelTag` nuevo: ícono + label apagados,
    SIN píldora, en la esquina de la fila superior (servicio manda
    a la izquierda con su píldora; el canal solo da contexto).
    Actualiza el ajuste 8: el canal ya no es solo del detalle —
    ahí sigue la píldora `AdminChannelChip`; la card usa la
    etiqueta susurro. En historial convive `[servicio] … [canal]
    [estado]` — canal antes del chip de estado.
15. **Header dentro del scroll** (decisión del dueño, revierte el
    "header fijo" de §10): `NestedScrollView` — caja + título +
    historial colapsan con el contenido y reflotan al subir
    (SIN floatHeaderSlivers — decisión del dueño: un toquecito no
    reflota el título; el header solo vuelve cuando el PRIMER
    pedido llega al tope y lo empuja); el strip de carriles queda
    "fijado" como FILA del body (ocupa layout, no overlay) — las
    cards se cortan limpio en su filo. La BANDA quedó: negro puro
    del scaffold cruzando el ancho completo — tapa la franja
    firma en esa fila, así que el scroll de chips es full-width
    (comportamiento aprobado por el dueño). Flecha
    "volver al inicio" tonal sobre el FAB cuando el carril supera
    ~2 cards (560px): sube las posiciones internas compartidas y
    reabre el header. Pull-to-refresh escucha cualquier depth
    vertical — con el nested el overscroll puede llegar por inner
    u outer.

---

## Orden de aplicación

1. `customer_order.dart` (+`ready`) + `admin_order.dart` (+serviceType)
2. `admin_day_close.dart` (entidad)
3. `admin_queue_state.dart` + `admin_queue_cubit.dart` (carriles + cierre + mocks)
4. `admin_order_action.dart` + `admin_order_chips.dart` (matriz + chips)
5. `admin_lane_strip.dart` + `admin_queue_lane.dart`
6. `admin_queue_screen.dart` (kanban + header) — elimina `admin_queue_filter.dart`
7. `admin_day_close_screen.dart` + `admin_history_screen.dart`
8. `app_router.dart` (rutas antes de `:id`)
9. `app_es.arb` + `flutter gen-l10n`
10. Tests + ajuste de los existentes
