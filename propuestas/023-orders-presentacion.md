# Propuesta: Pedidos — presentación (tab activo + historial + detalle)

Pantalla del tab **Pedidos** (hoy `ModulePlaceholderScreen`) en fase de
presentación: datos **mock** en el cubit, sin domain/data real todavía.
La integración llega por endpoint (backend 015: `GET /orders` míos,
`GET /orders/:id`, cancel en `pending`).

El lenguaje de estados ya existe en el backend (propuesta 013):
`pending → confirmed → preparing → done` (+ `cancelled`), service
`pickup | delivery`, pago `cash | transfer` con `pending | paid`.
La UI habla ese idioma — mapeo visual abajo.

**Decisiones ya tomadas con el usuario (encuesta previa a esta
propuesta):**

1. **Paso 4 según servicio**: en `done` el paso final se lee
   **"Listo"** en Local y **"Entregado"** en Domicilio — para el
   cliente lo que importa es saber cuándo pasar/recibir. Si en la
   integración `done` del backend solo significa "entregado al
   cliente", se propondrá `ready` al modelo (pendiente-modelo).
   En Domicilio **no hay "en camino"** — el backend no lo modela; el
   dueño marca `done` al entregar (decisión del usuario: vale así
   para el MVP).
2. **Cancelar solo en "Recibido"** (pending) — la regla del backend
   015; el botón desaparece cuando el local confirma. Diálogo de
   confirmación antes de cancelar.
3. **Sin "Volver a pedir"** — el usuario lo descartó para el MVP: el
   historial queda informativo; reordenar se evalúa después.
4. **2 pedidos en curso** en el mock (un domicilio "En la plancha" con
   pin y un local "Recibido" con botón cancelar) para ver ambos
   sabores + todos los estados visibles.
5. **Sin push ni polling real**: `RefreshIndicator` de pull-to-refresh
   simulado; el estado cambia cuando el dueño lo mueve (backend real
   en 015).

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/orders/domain/entities/customer_order.dart` | **nuevo** — entidad + enums (espejo del contrato backend) |
| `lib/features/orders/presentation/cubit/orders_state.dart` | **nuevo** — `OrdersState{active, history}` |
| `lib/features/orders/presentation/cubit/orders_cubit.dart` | **nuevo** — mock + `cancelOrder` |
| `lib/features/orders/presentation/utils/format_order_date.dart` | **nuevo** — "8 nov · 12:40 p. m." sin intl/locale |
| `lib/features/orders/presentation/widgets/order_status_chip.dart` | **nuevo** — píldora semántica por estado |
| `lib/features/orders/presentation/widgets/order_status_stepper.dart` | **nuevo** — dots+línea + label del paso actual |
| `lib/features/orders/presentation/widgets/active_order_card.dart` | **nuevo** — card "En curso" |
| `lib/features/orders/presentation/widgets/order_history_tile.dart` | **nuevo** — fila-pill de historial |
| `lib/features/orders/presentation/screens/orders_screen.dart` | **nuevo** — tab con secciones |
| `lib/features/orders/presentation/screens/order_detail_screen.dart` | **nuevo** — drill-down completo |
| `lib/core/routes/app_router.dart` | reemplaza placeholder + hija `:id` |
| `lib/core/di/setup_di.dart` | `registerFactory<OrdersCubit>` |
| `lib/l10n/app_es.arb` | +~30 claves `order*` |
| `test/features/orders/…` | cubit + screen tests |
| `Design/design-system.yaml` | bump + spec `status_stepper`/`orders` (al aprobar) |

---

## 1. customer_order.dart (archivo nuevo)

**Ruta:** `lib/features/orders/domain/entities/customer_order.dart`

```dart
import 'package:equatable/equatable.dart';

/// Estados de un pedido (espejo del enum `order_status` del backend,
/// propuesta 013): pending→received, confirmed→confirmed,
/// preparing→preparing, done→done, cancelled→cancelled.
/// El label del paso final varía por servicio: "Listo" en pickup,
/// "Entregado" en delivery (decisión del usuario — §023).
enum OrderStatus { received, confirmed, preparing, done, cancelled }

/// Cómo se entrega (espejo `order_service_type`; `dine_in` no aplica
/// a pedidos del cliente en la app — lo toma el dueño presencial).
enum OrderServiceType { pickup, delivery }

/// Cómo se paga (espejo `payment_method`): Nequi = transferencia
/// (push al celular); onDelivery = contra entrega (solo domicilio,
/// §022c).
enum OrderPaymentMethod { nequi, onDelivery }

/// Estado del pago (espejo `payment_status` subset relevante para el
/// cliente).
enum OrderPaymentStatus { pending, paid, failed }

/// Ítem snapshot de un pedido — lo que se cobró, no el producto vivo.
/// Los modificadores quedan como líneas de texto (mock §023; en la
/// integración viajan por optionId/action como CartModifier).
class OrderItem extends Equatable {
  const OrderItem({
    required this.productId,
    required this.productSlug,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.modifierLines = const [],
  });

  final String productId;
  final String productSlug;
  final String name;
  final int quantity;
  final int unitPrice;
  final List<String> modifierLines;

  int get lineTotal => unitPrice * quantity;

  @override
  List<Object?> get props => [
    productId,
    productSlug,
    name,
    quantity,
    unitPrice,
    modifierLines,
  ];
}

/// Pedido del cliente (contrato app ↔ backend 015, solo presentación
/// por ahora — los datos viven en mocks del cubit).
class CustomerOrder extends Equatable {
  const CustomerOrder({
    required this.id,
    required this.serviceType,
    required this.status,
    required this.items,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotal,
    required this.deliveryFee,
    required this.placedAt,
    this.statusChangedAt,
    this.addressLabel,
    this.landmark,
    this.neighborhood,
    this.hasLocationPin = false,
    this.note,
    this.cancelReason,
  });

  final String id;
  final OrderServiceType serviceType;
  final OrderStatus status;
  final List<OrderItem> items;
  final OrderPaymentMethod paymentMethod;
  final OrderPaymentStatus paymentStatus;
  final int subtotal;
  final int deliveryFee;
  final DateTime placedAt;
  final DateTime? statusChangedAt;

  /// Etiqueta de la ubicación guardada ("Casa", "Trabajo", "Casa de
  /// mi mamá") — solo delivery con guardada.
  final String? addressLabel;

  /// Punto de referencia de la entrega (§022a) — la zona no tiene
  /// direcciones formales.
  final String? landmark;
  final String? neighborhood;

  /// True si el pedido lleva pin de Google adjunto (§022d).
  final bool hasLocationPin;

  /// Observación del cliente para el local (§022a).
  final String? note;
  final String? cancelReason;

  int get total => subtotal + deliveryFee;
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  /// La cancelación del cliente solo existe mientras el local no
  /// confirma (regla backend 015 — pending, decisión del usuario).
  bool get isCancellable => status == OrderStatus.received;

  CustomerOrder copyWith({
    OrderStatus? status,
    DateTime? statusChangedAt,
    String? cancelReason,
  }) => CustomerOrder(
    id: id,
    serviceType: serviceType,
    status: status ?? this.status,
    items: items,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus,
    subtotal: subtotal,
    deliveryFee: deliveryFee,
    placedAt: placedAt,
    statusChangedAt: statusChangedAt ?? this.statusChangedAt,
    addressLabel: addressLabel,
    landmark: landmark,
    neighborhood: neighborhood,
    hasLocationPin: hasLocationPin,
    note: note,
    cancelReason: cancelReason ?? this.cancelReason,
  );

  @override
  List<Object?> get props => [
    id,
    serviceType,
    status,
    items,
    paymentMethod,
    paymentStatus,
    subtotal,
    deliveryFee,
    placedAt,
    statusChangedAt,
    addressLabel,
    landmark,
    neighborhood,
    hasLocationPin,
    note,
    cancelReason,
  ];
}
```

## 2. orders_state.dart (archivo nuevo)

**Ruta:** `lib/features/orders/presentation/cubit/orders_state.dart`

```dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/customer_order.dart';

/// Estado del tab Pedidos (§023, solo presentación): lista "En curso"
/// (no terminales — done/cancelled pasan al historial) + historial
/// más reciente primero.
class OrdersState extends Equatable {
  const OrdersState({this.active = const [], this.history = const []});

  /// Pedidos vivos (received/confirmed/preparing — el cliente sigue
  /// su progreso).
  final List<CustomerOrder> active;

  /// Pedidos terminados (done/cancelled), más reciente primero.
  final List<CustomerOrder> history;

  bool get isEmpty => active.isEmpty && history.isEmpty;

  OrdersState copyWith({
    List<CustomerOrder>? active,
    List<CustomerOrder>? history,
  }) => OrdersState(
    active: active ?? this.active,
    history: history ?? this.history,
  );

  @override
  List<Object?> get props => [active, history];
}
```

## 3. orders_cubit.dart (archivo nuevo)

**Ruta:** `lib/features/orders/presentation/cubit/orders_cubit.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/customer_order.dart';
import 'orders_state.dart';

/// Datos mock del tab Pedidos (§023, solo presentación). En la
/// integración vendrán de `GET /orders` del backend 015.

/// Domicilio "En la plancha" — con pin adjunto y Nequi pago.
final kMockOrderDelivery = CustomerOrder(
  id: 'ord-1',
  serviceType: OrderServiceType.delivery,
  status: OrderStatus.preparing,
  items: const [
    OrderItem(
      productId: 'p-cachorro',
      productSlug: 'cachorro',
      name: 'El Cachorro',
      quantity: 2,
      unitPrice: 14000,
      modifierLines: ['sin Queso mozzarella', '+ Salami'],
    ),
    OrderItem(
      productId: 'p-trampa',
      productSlug: 'trampa',
      name: 'La Trampa',
      quantity: 1,
      unitPrice: 16000,
    ),
  ],
  paymentMethod: OrderPaymentMethod.nequi,
  paymentStatus: OrderPaymentStatus.paid,
  subtotal: 44000,
  deliveryFee: 0,
  placedAt: DateTime(2026, 11, 8, 12, 40),
  statusChangedAt: DateTime(2026, 11, 8, 12, 52),
  addressLabel: 'Casa',
  landmark: 'Casa blanca frente a la cancha',
  neighborhood: 'Vereda El Carmen',
  hasLocationPin: true,
  note: 'pago con billete de 50, traer cambio',
);

/// Local "Recibido" — muestra el botón cancelar (única ventana).
final kMockOrderPickup = CustomerOrder(
  id: 'ord-2',
  serviceType: OrderServiceType.pickup,
  status: OrderStatus.received,
  items: const [
    OrderItem(
      productId: 'p-depredador',
      productSlug: 'depredador',
      name: 'El Depredador',
      quantity: 1,
      unitPrice: 25000,
      modifierLines: ['+ Tocineta crocante'],
    ),
  ],
  paymentMethod: OrderPaymentMethod.nequi,
  paymentStatus: OrderPaymentStatus.pending,
  subtotal: 25000,
  deliveryFee: 0,
  placedAt: DateTime(2026, 11, 8, 13, 10),
  statusChangedAt: DateTime(2026, 11, 8, 13, 10),
);

final kMockHistory = <CustomerOrder>[
  CustomerOrder(
    id: 'ord-3',
    serviceType: OrderServiceType.delivery,
    status: OrderStatus.done,
    items: const [
      OrderItem(
        productId: 'p-coyote',
        productSlug: 'coyote',
        name: 'El Coyote',
        quantity: 2,
        unitPrice: 18000,
        modifierLines: ['sin Huevo de codorniz'],
      ),
    ],
    paymentMethod: OrderPaymentMethod.onDelivery,
    paymentStatus: OrderPaymentStatus.paid,
    subtotal: 36000,
    deliveryFee: 0,
    placedAt: DateTime(2026, 11, 7, 18, 32),
    statusChangedAt: DateTime(2026, 11, 7, 19, 5),
    addressLabel: 'Trabajo',
    landmark: 'Segundo local del puente hacia arriba',
    neighborhood: 'Centro',
  ),
  CustomerOrder(
    id: 'ord-4',
    serviceType: OrderServiceType.pickup,
    status: OrderStatus.done,
    items: const [
      OrderItem(
        productId: 'p-cachorro',
        productSlug: 'cachorro',
        name: 'El Cachorro',
        quantity: 1,
        unitPrice: 14000,
      ),
    ],
    paymentMethod: OrderPaymentMethod.nequi,
    paymentStatus: OrderPaymentStatus.paid,
    subtotal: 14000,
    deliveryFee: 0,
    placedAt: DateTime(2026, 11, 4, 20, 15),
    statusChangedAt: DateTime(2026, 11, 4, 20, 40),
  ),
  CustomerOrder(
    id: 'ord-5',
    serviceType: OrderServiceType.delivery,
    status: OrderStatus.cancelled,
    cancelReason: 'Cancelado por el cliente',
    items: const [
      OrderItem(
        productId: 'p-ave',
        productSlug: 'ave-de-presa',
        name: 'Ave de Presa',
        quantity: 2,
        unitPrice: 18000,
      ),
    ],
    paymentMethod: OrderPaymentMethod.onDelivery,
    paymentStatus: OrderPaymentStatus.pending,
    subtotal: 36000,
    deliveryFee: 0,
    placedAt: DateTime(2026, 11, 1, 19, 0),
    statusChangedAt: DateTime(2026, 11, 1, 19, 3),
    landmark: 'Frente a la farmacia',
  ),
];

/// SOLID (SRP): único dueño del estado del tab Pedidos (§023) —
/// listas activo/historial y la acción de pantalla (cancelar).
/// FACTORY en el route — estado de pantalla.
class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({
    List<CustomerOrder>? seedActive,
    List<CustomerOrder>? seedHistory,
  }) : super(
         OrdersState(
           active: seedActive ?? [kMockOrderDelivery, kMockOrderPickup],
           history: seedHistory ?? kMockHistory,
         ),
       );

  /// Cancela un pedido "Recibido" (§023 mock — la llamada real es
  /// `PATCH /orders/:id/cancel` del backend 015, solo válido en
  /// pending). El pedido migra de En curso al historial como
  /// cancelado.
  void cancelOrder(String orderId) {
    final index = state.active.indexWhere((o) => o.id == orderId);
    if (index < 0 || !state.active[index].isCancellable) return;
    final cancelled = state.active[index].copyWith(
      status: OrderStatus.cancelled,
      statusChangedAt: DateTime.now(),
      cancelReason: 'Cancelado por el cliente',
    );
    emit(
      state.copyWith(
        active: state.active.where((o) => o.id != orderId).toList(),
        history: [cancelled, ...state.history],
      ),
    );
  }
}
```

## 4. format_order_date.dart (archivo nuevo)

**Ruta:** `lib/features/orders/presentation/utils/format_order_date.dart`

```dart
/// "8 nov · 12:40 p. m." — formato de fecha corto es-CO para pedidos
/// (§023). La app no inicializa locales de `intl` (DateFormat('es')
/// lanzaría LocaleDataException), así que los meses cortos se declaran
/// acá — único archivo autorizado para formatear fechas de pedidos.
String formatOrderDate(DateTime date, {bool withYear = false}) {
  const months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final ampm = date.hour < 12 ? 'a. m.' : 'p. m.';
  final year = withYear ? ' ${date.year}' : '';
  return '${date.day} ${months[date.month - 1]}$year · $hour12:$minute $ampm';
}
```

## 5. order_status_chip.dart (archivo nuevo)

**Ruta:** `lib/features/orders/presentation/widgets/order_status_chip.dart`

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/customer_order.dart';

/// Píldora de estado del pedido (§023): label + tinte semántico.
/// En curso = primary (la atención viva); done = tertiary (verde
/// pepinillo del sistema — token, no hex); cancelled = error.
/// `muted` (historial): mismo tinte a α0.55 — los terminales son
/// evidencia, no acción (semántica honesta del drill-down).
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({
    required this.order,
    this.muted = false,
    super.key,
  });

  final CustomerOrder order;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final fade = muted ? 0.55 : 1.0;
    final (label, bg, fg) = switch (order.status) {
      OrderStatus.received || OrderStatus.confirmed => (
        order.status == OrderStatus.received
            ? l10n.orderStatusReceived
            : l10n.orderStatusConfirmed,
        colors.primary.withValues(alpha: 0.14 * fade),
        colors.primary.withValues(alpha: fade),
      ),
      OrderStatus.preparing => (
        l10n.orderStatusPreparing,
        colors.primary.withValues(alpha: 0.22 * fade),
        colors.primary.withValues(alpha: fade),
      ),
      OrderStatus.done => (
        order.serviceType == OrderServiceType.pickup
            ? l10n.orderStatusReady
            : l10n.orderStatusDelivered,
        colors.tertiary.withValues(alpha: 0.18 * fade),
        colors.tertiary.withValues(alpha: fade),
      ),
      OrderStatus.cancelled => (
        l10n.orderStatusCancelled,
        colors.error.withValues(alpha: 0.14 * fade),
        colors.error.withValues(alpha: fade),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
```

## 6. order_status_stepper.dart (archivo nuevo)

**Ruta:** `lib/features/orders/presentation/widgets/order_status_stepper.dart`

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/customer_order.dart';

/// Progreso del pedido activo (§023): fila de 4 dots unidos por
/// línea — pasados y actual rellenos primary (pasados con check),
/// futuros outline — y debajo el label del paso ACTUAL centrado.
///
/// Decisión de layout: los 4 labels bajo los dots NO caben en la
/// zona negra (~250dp internos de card — "En la plancha" truncaría
/// "Confirmado"); el headline del paso actual comunica lo mismo sin
/// partir palabras — el patrón summary→detail: el resumen muestra el
/// ahora, el detalle completo vive en la pantalla hija.
///
/// `cancelled` no entra al stepper — la card/detalle lo muestran en
/// el chip con la razón debajo.
class OrderStatusStepper extends StatelessWidget {
  const OrderStatusStepper({required this.order, super.key});

  final CustomerOrder order;

  /// Índice del paso actual (0-3); done = último completo.
  int get _step => switch (order.status) {
    OrderStatus.received => 0,
    OrderStatus.confirmed => 1,
    OrderStatus.preparing => 2,
    OrderStatus.done || OrderStatus.cancelled => 3,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final label = switch (order.status) {
      OrderStatus.received => l10n.orderStepReceived,
      OrderStatus.confirmed => l10n.orderStepConfirmed,
      OrderStatus.preparing => l10n.orderStepPreparing,
      OrderStatus.done => order.serviceType == OrderServiceType.pickup
          ? l10n.orderStepReady
          : l10n.orderStepDelivered,
      OrderStatus.cancelled => l10n.orderStatusCancelled,
    };
    return Semantics(
      label: label,
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: i <= _step
                          ? colors.primary
                          : colors.outlineVariant,
                    ),
                  ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= _step
                        ? colors.primary
                        : Colors.transparent,
                    border: i <= _step
                        ? null
                        : Border.all(
                            color: colors.outlineVariant,
                            width: 2,
                          ),
                  ),
                  child: i < _step
                      ? Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: colors.onPrimary,
                        )
                      : null,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: order.status == OrderStatus.cancelled
                  ? colors.error
                  : colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
```

## 7. active_order_card.dart (archivo nuevo)

**Ruta:** `lib/features/orders/presentation/widgets/active_order_card.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../domain/entities/customer_order.dart';
import '../cubit/orders_cubit.dart';
import 'order_status_chip.dart';
import 'order_status_stepper.dart';

/// Card del pedido "En curso" (§023): servicio + chip de estado,
/// stepper, resumen de ítems, entrega (referencia o local), pago y
/// observación. Tap → detalle (`/orders/:id`, drill-down con extra).
/// "Cancelar pedido" solo vive en "Recibido" (regla backend: cancel
/// en pending) con diálogo de confirmación — decisión del usuario:
/// la cancelación no es un botón permanente.
class ActiveOrderCard extends StatelessWidget {
  const ActiveOrderCard({required this.order, super.key});

  final CustomerOrder order;

  Future<void> _confirmCancel(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.orderCancelTitle),
        content: Text(l10n.orderCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.orderCancelKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  Theme.of(dialogContext).colorScheme.error,
              foregroundColor:
                  Theme.of(dialogContext).colorScheme.onError,
            ),
            child: Text(l10n.orderCancelConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<OrdersCubit>().cancelOrder(order.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDelivery = order.serviceType == OrderServiceType.delivery;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push(
          '${AuthGuard.ordersRoute}/${order.id}',
          extra: order,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isDelivery
                        ? Icons.moped_rounded
                        : Icons.storefront_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isDelivery
                        ? l10n.orderServiceDelivery
                        : l10n.orderServicePickup,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  OrderStatusChip(order: order),
                ],
              ),
              const SizedBox(height: 14),
              OrderStatusStepper(order: order),
              const SizedBox(height: 12),
              // Resumen: "2× El Cachorro, 1× La Trampa" + total.
              Text(
                order.items
                    .map((i) => '${i.quantity}× ${i.name}')
                    .join(', '),
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _DeliveryLine(order: order)),
                  const SizedBox(width: 8),
                  Text(
                    formatCop(order.total),
                    style: text.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _PaymentLine(order: order),
              if (order.isCancellable) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _confirmCancel(context),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.error,
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(l10n.orderCancelCta),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Línea de entrega: domicilio = referencia (+ pin si adjunto);
/// local = "lo recoges en el local".
class _DeliveryLine extends StatelessWidget {
  const _DeliveryLine({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    if (order.serviceType == OrderServiceType.pickup) {
      return Row(
        children: [
          Icon(Icons.storefront_rounded, size: 14, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.orderPickupAtStore,
              style: text.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.place_outlined, size: 14, color: muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                [
                  if (order.addressLabel != null) order.addressLabel!,
                  if (order.landmark != null) order.landmark!,
                ].join(' — '),
                style: text.bodySmall?.copyWith(color: muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (order.hasLocationPin)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 2),
            child: Text(
              l10n.orderWithLocationPin,
              style: text.labelSmall?.copyWith(color: colors.primary),
            ),
          ),
      ],
    );
  }
}

/// Línea de pago: método + estado ("Nequi · pagado" / "Pagas al
/// recibir" / "Nequi · pago pendiente").
class _PaymentLine extends StatelessWidget {
  const _PaymentLine({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    final label = switch ((order.paymentMethod, order.paymentStatus)) {
      (OrderPaymentMethod.nequi, OrderPaymentStatus.paid) =>
        l10n.orderPaymentNequiPaid,
      (OrderPaymentMethod.nequi, _) => l10n.orderPaymentNequiPending,
      (OrderPaymentMethod.onDelivery, _) => l10n.orderPaymentOnDelivery,
    };
    return Row(
      children: [
        Icon(
          order.paymentMethod == OrderPaymentMethod.nequi
              ? Icons.smartphone_rounded
              : Icons.payments_rounded,
          size: 14,
          color: muted,
        ),
        const SizedBox(width: 6),
        Text(label, style: text.bodySmall?.copyWith(color: muted)),
      ],
    );
  }
}
```

## 8. order_history_tile.dart (archivo nuevo)

**Ruta:** `lib/features/orders/presentation/widgets/order_history_tile.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../domain/entities/customer_order.dart';
import '../utils/format_order_date.dart';
import 'order_status_chip.dart';

/// Fila-pill del historial (§023 — idioma "filas-pill" del
/// summary-drilldown): servicio + fecha + N ítems + total + chip de
/// estado atenuado (terminal = evidencia) + chevron → detalle.
class OrderHistoryTile extends StatelessWidget {
  const OrderHistoryTile({required this.order, super.key});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDelivery = order.serviceType == OrderServiceType.delivery;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push(
          '${AuthGuard.ordersRoute}/${order.id}',
          extra: order,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(
                isDelivery
                    ? Icons.moped_rounded
                    : Icons.storefront_rounded,
                size: 18,
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatOrderDate(order.placedAt),
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      l10n.orderItemsCount(order.itemCount),
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCop(order.total),
                    style: text.bodyMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  OrderStatusChip(order: order, muted: true),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 9. orders_screen.dart (archivo nuevo)

**Ruta:** `lib/features/orders/presentation/screens/orders_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/customization_section.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../cubit/orders_cubit.dart';
import '../cubit/orders_state.dart';
import '../widgets/active_order_card.dart';
import '../widgets/order_history_tile.dart';

/// Tab Pedidos (§023, presentación mock): título naciente +
/// CustomizationSection "En curso" (cards activas) + "Historial"
/// (filas-pill → detalle). Vacío = ícono + CTA al menú. Pull-to-
/// refresh simulado (la fuente real es GET /orders del backend 015).
/// Es tab — no lleva flecha back (familia home).
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          BlocBuilder<OrdersCubit, OrdersState>(
            builder: (context, state) {
              if (state.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _OrdersTitle(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => Padding(
                          padding: EdgeInsets.only(
                            left: c.maxWidth * kSignatureStripFraction,
                          ),
                          child: Center(child: _OrdersEmpty(l10n: l10n)),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _OrdersTitle(),
                  Expanded(
                    child: RefreshIndicator(
                      color: colors.primary,
                      onRefresh: () async {
                        // Mock §023 — la integración hace refetch de
                        // GET /orders.
                        await Future<void>.delayed(
                          const Duration(milliseconds: 400),
                        );
                      },
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          if (state.active.isNotEmpty)
                            CustomizationSection(
                              title: l10n.ordersSectionActive,
                              children: [
                                for (final order in state.active)
                                  ActiveOrderCard(order: order),
                              ],
                            ),
                          if (state.history.isNotEmpty)
                            CustomizationSection(
                              title: l10n.ordersSectionHistory,
                              children: [
                                for (final order in state.history)
                                  OrderHistoryTile(order: order),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Título "Pedidos" naciendo de la franja — mismo patrón que
/// `_CartTitle` (FractionallySizedBox en la zona negra, dentro del
/// frame fijo, no del scroll).
class _OrdersTitle extends StatelessWidget {
  const _OrdersTitle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.602,
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.ordersTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.headlineSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vista vacía (§023): recibo + copy de marca + CTA al menú — el
/// mismo motivo del carrito vacío (ícono primary + título + sub +
/// FilledButton).
class _OrdersEmpty extends StatelessWidget {
  const _OrdersEmpty({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 44,
            color: colors.primary.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.ordersEmptyTitle,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.ordersEmptySubtitle,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => context.go(AuthGuard.homeRoute),
            icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
            label: Text(l10n.ordersBrowseMenu),
          ),
        ],
      ),
    );
  }
}
```

## 10. order_detail_screen.dart (archivo nuevo)

**Ruta:** `lib/features/orders/presentation/screens/order_detail_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../../home/presentation/widgets/customization_section.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../domain/entities/customer_order.dart';
import '../utils/format_order_date.dart';
import '../widgets/order_status_chip.dart';
import '../widgets/order_status_stepper.dart';

/// Detalle del pedido (§023 — drill-down del tab, push slideUp como
/// cart/checkout): estado con stepper (o chip + razón si cancelado),
/// ítems completos con modificadores, entrega + pago, observación y
/// totales. La ruta lleva `extra: CustomerOrder`; el back regresa al
/// tab. SIN "volver a pedir" — descartado por el usuario para el MVP.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({required this.order, super.key});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isCancelled = order.status == OrderStatus.cancelled;
    return Scaffold(
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DetailTitle(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    CustomizationSection(
                      title: l10n.orderDetailStatusSection,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            14, 8, 14, 14,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      formatOrderDate(
                                        order.placedAt,
                                        withYear: true,
                                      ),
                                      style: text.bodySmall?.copyWith(
                                        color: colors.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                  OrderStatusChip(order: order),
                                ],
                              ),
                              if (!isCancelled) ...[
                                const SizedBox(height: 14),
                                OrderStatusStepper(order: order),
                              ],
                              if (isCancelled &&
                                  order.cancelReason != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  order.cancelReason!,
                                  style: text.bodySmall?.copyWith(
                                    color: colors.error.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    CustomizationSection(
                      title: l10n.orderDetailItemsSection,
                      children: [
                        for (final item in order.items)
                          _ItemLine(item: item),
                        Divider(
                          height: 24,
                          indent: 14,
                          endIndent: 14,
                          color: colors.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        _Totals(order: order),
                      ],
                    ),
                    CustomizationSection(
                      title: l10n.orderDetailDeliverySection,
                      children: [_DeliveryDetail(order: order)],
                    ),
                    if (order.note != null && order.note!.isNotEmpty)
                      CustomizationSection(
                        title: l10n.orderDetailNoteSection,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              14, 6, 14, 12,
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.sticky_note_2_outlined,
                                  size: 16,
                                  color: colors.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    order.note!,
                                    style: text.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 4,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: colors.onPrimary,
              ),
              tooltip: l10n.catalogBackTooltip,
              onPressed: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Título "Detalle del pedido" — mismo patrón scrolling_title que
/// cart/checkout (zona negra, fijo sobre el scroll).
class _DetailTitle extends StatelessWidget {
  const _DetailTitle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.602,
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.orderDetailTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.headlineSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ítem del pedido: "2× El Cachorro" + líneas de modificadores +
/// lineTotal.
class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.quantity}× ${item.name}',
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                for (final line in item.modifierLines)
                  Text(
                    line,
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatCop(item.lineTotal),
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtotal / domicilio ("Gratis" primary) / total — mismo idioma del
/// resumen del checkout.
class _Totals extends StatelessWidget {
  const _Totals({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        children: [
          _row(text, colors, l10n.orderSummarySubtotal,
              formatCop(order.subtotal)),
          if (order.serviceType == OrderServiceType.delivery)
            _row(
              text,
              colors,
              l10n.orderSummaryDelivery,
              order.deliveryFee == 0
                  ? l10n.orderSummaryFree
                  : formatCop(order.deliveryFee),
              valuePrimary: order.deliveryFee == 0,
            ),
          const SizedBox(height: 4),
          _row(text, colors, l10n.orderSummaryTotal,
              formatCop(order.total), total: true),
        ],
      ),
    );
  }

  Widget _row(
    TextTheme text,
    ColorScheme colors,
    String label,
    String value, {
    bool valuePrimary = false,
    bool total = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: (total ? text.titleSmall : text.bodySmall)?.copyWith(
              color: total
                  ? colors.onSurface
                  : colors.onSurface.withValues(alpha: 0.7),
              fontWeight: total ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: (total ? text.titleSmall : text.bodySmall)?.copyWith(
            color: valuePrimary || total
                ? colors.primary
                : colors.onSurface,
            fontWeight:
                total || valuePrimary ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

/// Bloque "Entrega y pago" del detalle: servicio + referencia completa
/// (etiqueta / punto de referencia / barrio / pin) o local, y método
/// + estado de pago.
class _DeliveryDetail extends StatelessWidget {
  const _DeliveryDetail({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    final isDelivery = order.serviceType == OrderServiceType.delivery;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDelivery
                    ? Icons.moped_rounded
                    : Icons.storefront_rounded,
                size: 16,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isDelivery
                    ? l10n.orderServiceDelivery
                    : l10n.orderServicePickup,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isDelivery) ...[
            if (order.addressLabel != null)
              Text(order.addressLabel!, style: text.bodyMedium),
            if (order.landmark != null)
              Text(
                order.landmark!,
                style: text.bodyMedium?.copyWith(color: muted),
              ),
            if (order.neighborhood != null)
              Text(
                order.neighborhood!,
                style: text.bodySmall?.copyWith(color: muted),
              ),
            if (order.hasLocationPin)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.orderWithLocationPin,
                      style: text.bodySmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ] else
            Text(
              l10n.orderPickupAtStore,
              style: text.bodyMedium?.copyWith(color: muted),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                order.paymentMethod == OrderPaymentMethod.nequi
                    ? Icons.smartphone_rounded
                    : Icons.payments_rounded,
                size: 16,
                color: muted,
              ),
              const SizedBox(width: 8),
              Text(
                switch ((order.paymentMethod, order.paymentStatus)) {
                  (OrderPaymentMethod.nequi, OrderPaymentStatus.paid) =>
                    l10n.orderPaymentNequiPaid,
                  (OrderPaymentMethod.nequi, _) =>
                    l10n.orderPaymentNequiPending,
                  (OrderPaymentMethod.onDelivery, _) =>
                    l10n.orderPaymentOnDelivery,
                },
                style: text.bodyMedium?.copyWith(color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

## 11. app_router.dart (archivo existente — actualización)

**Ruta:** `lib/core/routes/app_router.dart`

**Antes:**
```dart
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AuthGuard.ordersRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  state,
                  ModulePlaceholderScreen(
                    icon: Icons.receipt_long_rounded,
                    moduleLabel: AppLocalizations.of(context)!.shellTabOrders,
                  ),
                ),
              ),
            ],
          ),
```

**Después:**
```dart
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AuthGuard.ordersRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  state,
                  BlocProvider(
                    create: (_) => locator<OrdersCubit>(),
                    child: const OrdersScreen(),
                  ),
                ),
                routes: [
                  // Detalle del pedido (§023 drill-down) — hija del
                  // tab, conserva shell + nav; extra = CustomerOrder.
                  // Deep link sin extra → al tab (igual que cart/edit).
                  GoRoute(
                    path: ':id',
                    redirect: (context, state) =>
                        state.extra is CustomerOrder
                        ? null
                        : AuthGuard.ordersRoute,
                    pageBuilder: (context, state) =>
                        CustomTransitions.slideUp(
                          state,
                          OrderDetailScreen(
                            order: state.extra! as CustomerOrder,
                          ),
                        ),
                  ),
                ],
              ),
            ],
          ),
```

(imports nuevos: `OrdersScreen`, `OrderDetailScreen`, `CustomerOrder`,
`OrdersCubit`; `ModulePlaceholderScreen` queda solo para Perfil.)

## 12. setup_di.dart (archivo existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

**Después** (junto al `registerFactory<CheckoutCubit>`):
```dart
  // Pedidos (§023): factory por apertura del tab — estado de pantalla
  // con mocks hasta la integración de GET /orders (backend 015).
  locator.registerFactory<OrdersCubit>(() => OrdersCubit());
```

## 13. app_es.arb (archivo existente — +claves)

**Ruta:** `lib/l10n/app_es.arb`

```json
  "ordersTitle": "Pedidos",
  "ordersSectionActive": "En curso",
  "ordersSectionHistory": "Historial",
  "ordersEmptyTitle": "Aún no has pedido",
  "ordersEmptySubtitle": "Tu próximo antojo empieza en el menú",
  "ordersBrowseMenu": "Ver el menú",
  "orderServicePickup": "Local",
  "orderServiceDelivery": "Domicilio",
  "orderStatusReceived": "Recibido",
  "orderStatusConfirmed": "Confirmado",
  "orderStatusPreparing": "En la plancha",
  "orderStatusReady": "Listo",
  "orderStatusDelivered": "Entregado",
  "orderStatusCancelled": "Cancelado",
  "orderStepReceived": "Recibido",
  "orderStepConfirmed": "Confirmado",
  "orderStepPreparing": "En la plancha",
  "orderStepReady": "Listo — ya puedes pasar",
  "orderStepDelivered": "Entregado",
  "orderPickupAtStore": "Lo recoges en el local",
  "orderWithLocationPin": "Con ubicación de Google",
  "orderPaymentNequiPaid": "Nequi · pagado",
  "orderPaymentNequiPending": "Nequi · pago pendiente",
  "orderPaymentOnDelivery": "Pagas al recibir",
  "orderItemsCount": "{count, plural, =1{1 ítem} other{{count} ítems}}",
  "orderCancelCta": "Cancelar pedido",
  "orderCancelTitle": "¿Cancelar el pedido?",
  "orderCancelBody": "El local aún no lo confirma — puedes cancelar sin problema.",
  "orderCancelConfirm": "Sí, cancelar",
  "orderCancelKeep": "No, dejarlo",
  "orderDetailTitle": "Detalle del pedido",
  "orderDetailStatusSection": "Estado",
  "orderDetailItemsSection": "Tu pedido",
  "orderDetailDeliverySection": "Entrega y pago",
  "orderDetailNoteSection": "Observación",
  "orderSummarySubtotal": "Subtotal",
  "orderSummaryDelivery": "Domicilio",
  "orderSummaryFree": "Gratis",
  "orderSummaryTotal": "Total"
```
(+ sus `@key` con description; `flutter gen-l10n` regenera. Plural
con la sintaxis `=1{...} other{...}` de `catalogProductsCount`.)

## 14. Tests (archivos nuevos)

**Rutas:**
`test/features/orders/presentation/cubit/orders_cubit_test.dart`
`test/features/orders/presentation/screens/orders_screen_test.dart`

Cobertura:
- Cubit: estado inicial (2 activos + 3 historial); `cancelOrder` mueve
  el pickup a historial como cancelled (cabeza de la lista) y **no**
  cancela el que está en preparing (regla pending); semillas vacías
  → `isEmpty`.
- Screen (misma mecánica del suite de checkout — MaterialApp +
  BlocProvider con cubit semilla, helper `scrollTo` por lazy list):
  secciones En curso/Historial; el delivery muestra el paso 3 activo
  + referencia + "Con ubicación de Google" + "Nequi · pagado"; el
  pickup muestra "Cancelar pedido" y el delivery no; diálogo confirma
  y la card pasa a Historial como Cancelado; fila del historial con
  chip atenuado; tap → `context.push` invocado (GoRouter de test o
  `MockGoRouter` según patrón del suite — se verifica el destino
  `/orders/ord-1`); vacío → "Ver el menú".
- Detail (screen test propio con `CustomerOrder` semilla): secciones
  Estado/Tu pedido/Entrega y pago/Observación; cancelado → chip +
  razón sin stepper; totales con "Gratis" primary.

## Orden de aplicación

1. `customer_order.dart` → `orders_state.dart` → `orders_cubit.dart`
   → `format_order_date.dart`
2. widgets (`status_chip` → `stepper` → `active_card` → `history_tile`)
3. `orders_screen.dart` → `order_detail_screen.dart`
4. `app_router.dart` + `setup_di.dart` + `app_es.arb` (`gen-l10n`)
5. tests → `dart format` → `flutter analyze` → `flutter test`
6. Verificación visual en emulador (En curso / Historial / detalle /
   cancelar / vacío) → gate revisor-estetico + revisor-ui → usuario
7. `design-system.yaml` bump + spec `status_stepper` + commit

**Pendientes que deja la fase** (para `pendientes/` si aplican):
- `GET /orders` real + refresco (pull-to-refresh hoy es simulado).
- Cancel real `PATCH /orders/:id/cancel`.
- Push/notify cuando el dueño mueve el estado.
- `done` para pickup = "Listo" — confirmar semántica con backend 015
  (si `done` es solo "entregado", proponer `ready` vía
  modelo-evolución).
- "Volver a pedir" — evaluado y pospuesto por el usuario (la
  revalidación real requeriría catálogo vivo).

## Anexo §023a — revisión post-implementación (revisor-estetico + revisor-ui + decisiones del usuario)

**Aprobación visual del usuario: SÍ** (tab + detalle + cancelar + panel de ítems).

### Revisor-estetico (aplicado antes del gate técnico)

- Cada pedido activo es SU PROPIA straddle_card con la imagen del
  primer ítem flotante a caballo del borde izquierdo — DIRECCIÓN
  aprobada por el usuario (antes: una sección-card para todos).
- El stepper queda GRÁFICA PURA: el caption duplicaba el chip de
  estado a ~60dp; el progreso vive en Semantics ("Paso N de 4: …").
- Pickup muestra `storeReference` real ("Depredadog — Costado norte
  del parque principal") — la frase genérica duplicaba el header.
- Títulos "Pedidos"/"Detalle del pedido" dentro del ListView
  (scrolling_title de la familia — antes fijos sobre el scroll).
- Heading "En curso" retirado: el título pelado caía mostaza sobre
  franja mostaza y las cards ya se auto-explican.
  `ordersSectionActive` muerta en l10n.

### Revisor-ui (3 IMPORTANTE + 7 MENOR — todos corregidos)

- Cancelar también vive en el DETALLE (el drill-down no puede ser
  menos capaz que la card): diálogo compartido
  `showOrderCancelDialog` + `AppToast.info("Pedido cancelado")` +
  pop al tab ya migrado.
- `OrdersCubit` registerFactory → lazySingleton + BlocProvider.value
  en ambas rutas (patrón CartCubit) — requisito del punto anterior.
- Chip muted del historial: bg 0.55 / fg 0.8 (contraste ≥AA — antes
  ~3:1).
- "Pagas al recibir" → "Pagaste al recibir" en estados terminales
  (`isTerminal` nuevo en la entidad).
- Fecha del detalle: `Pedido el {date}` prefijado + año solo si ≠
  año en curso (era `placedAt` pelado bajo "Estado" — se leía como
  fecha del cambio).
- Stepper anuncia "Paso N de 4: <estado>" a TalkBack.
- Vacío alineado al carrito (gaps 12/4/16 + `FilledButton.tonalIcon`).
- Aire 10dp antes del botón cancelar; chevron del historial 0.4→0.65;
  ícono de la línea pickup → `place_outlined` (storefront duplicado).

### Decisiones del usuario durante la revisión

- Mock `ord-6` nuevo: domicilio "Confirmado" pagando EFECTIVO contra
  entrega — la única vía donde existe efectivo (§022c). Cubre las 3
  combinaciones de pago visibles (Nequi pagado / Nequi pendiente /
  efectivo) y el paso Confirmed del stepper.
- Ítems del detalle "como en el carrito" (decisión del usuario —
  verificar qué quedó en cada perro): `OrderItem.modifierLines`
  (texto plano) → `modifiers: List<CartModifier>` + `includedNames`
  — la MISMA estructura del CartItem, 1:1 con `order_item_modifiers`
  del backend 013. Cada ítem gana el chip "Detalle" (píldora
  outlined + chevron, hit 40dp) → `OrderItemDetailPanel` por
  secciones (Ingredientes / Se le quitó / Adicionales / Toppings /
  Salsas, puntos mostaza, +precio primary, reemplazos "agotado →
  reemplazo") — solo lectura, SIN "Editar" (el pedido ya se cobró).

### Estado final verificado

- `flutter analyze`: limpio. Suite completa verde (14 tests de
  orders: 5 cubit + 9 screen).
- Verificado en emulador: 3 straddle cards activas (preparing Nequi
  pagado + received Nequi pendiente cancelable + confirmed efectivo),
  historial drill-down, cancelar desde card y desde detalle con
  toast, panel del ítem por secciones, vacío con CTA.
- `design-system.yaml` → 1.30.0 con spec orders completo.

### Pendientes que quedan para la integración (backend 015)

- `GET /orders` míos + loading/error/empty reales (hoy el estado no
  emite fallos; el pull-to-refresh es simulado 400ms).
- `PATCH /orders/:id/cancel` real + manejo de errores.
- Refresco por push/notify cuando el dueño mueve el estado.
- Confirmar semántica `done` para pickup ("Listo") vs "entregado"
  (pendiente-modelo documentado en la propuesta).
- "Volver a pedir" — pospuesto por el usuario.

## Anexo §023a — revisión post-implementación (revisor-estetico + revisor-ui + decisiones del usuario)

**Aprobación visual del usuario: SÍ** (tab + detalle + cancelar + panel de ítems).

### Revisor-estetico (aplicado antes del gate técnico)

- Cada pedido activo es SU PROPIA straddle_card con la imagen del
  primer ítem flotante a caballo del borde izquierdo — DIRECCIÓN
  aprobada por el usuario (antes: una sección-card para todos).
- El stepper queda GRÁFICA PURA: el caption duplicaba el chip de
  estado a ~60dp; el progreso vive en Semantics ('Paso N de 4: …').
- Pickup muestra  real ('Depredadog — Costado norte
  del parque principal') — la frase genérica duplicaba el header.
- Títulos 'Pedidos'/'Detalle del pedido' dentro del ListView
  (scrolling_title de la familia — antes fijos sobre el scroll).
- Heading 'En curso' retirado: el título pelado caía mostaza sobre
  franja mostaza y las cards ya se auto-explican.
   muerta en l10n.

### Revisor-ui (3 IMPORTANTE + 7 MENOR — todos corregidos)

- Cancelar también vive en el DETALLE (el drill-down no puede ser
  menos capaz que la card): diálogo compartido
   +  +
  pop al tab ya migrado.
-  registerFactory → lazySingleton + BlocProvider.value
  en ambas rutas (patrón CartCubit) — requisito del punto anterior.
- Chip muted del historial: bg 0.55 / fg 0.8 (contraste ≥AA — antes
  ~3:1).
- 'Pagas al recibir' → 'Pagaste al recibir' en estados terminales
  (isTerminal nuevo en la entidad).
- Fecha del detalle: 'Pedido el {date}' prefijado + año solo si ≠
  año en curso (era placedAt pelado bajo 'Estado' — se leía como
  fecha del cambio).
- Stepper anuncia 'Paso N de 4: <estado>' a TalkBack.
- Vacío alineado al carrito (gaps 12/4/16 + FilledButton.tonalIcon).
- Aire 10dp antes del botón cancelar; chevron del historial 0.4→0.65;
  ícono de la línea pickup → place_outlined (storefront duplicado).

### Decisiones del usuario durante la revisión

- Mock  nuevo: domicilio 'Confirmado' pagando EFECTIVO contra
  entrega — la única vía donde existe efectivo (§022c). Cubre las 3
  combinaciones de pago visibles (Nequi pagado / Nequi pendiente /
  efectivo) y el paso Confirmed del stepper.
- Ítems del detalle 'como en el carrito' (decisión del usuario —
  verificar qué quedó en cada perro): 
  (texto plano) →  + 
  — la MISMA estructura del CartItem, 1:1 con order_item_modifiers
  del backend 013. Cada ítem gana el chip 'Detalle' (píldora
  outlined + chevron, hit 40dp) →  por
  secciones (Ingredientes / Se le quitó / Adicionales / Toppings /
  Salsas, puntos mostaza, +precio primary, reemplazos 'agotado →
  reemplazo') — solo lectura, SIN 'Editar' (el pedido ya se cobró).

### Estado final verificado

- Analyzing pcalientes_app...                                     
No issues found! (ran in 50.2s): limpio. Suite completa: 344+1 tests verdes
  (14 de orders: 5 cubit + 9 screen).
- Verificado en emulador: 3 straddle cards activas (preparing Nequi
  pagado + received Nequi pendiente cancelable + confirmed efectivo),
  historial drill-down, cancelar desde card y desde detalle con
  toast, panel del ítem por secciones, vacío con CTA.
-  → 1.30.0 con spec orders completo.

### Pendientes que quedan para la integración (backend 015)

-  míos + loading/error/empty reales (hoy el estado no
  emite fallos; el pull-to-refresh es simulado 400ms).
-  real + manejo de errores.
- Refresco por push/notify cuando el dueño mueve el estado.
- Confirmar semántica  para pickup ('Listo') vs 'entregado'
  (pendiente-modelo documentado en la propuesta).
- 'Volver a pedir' — pospuesto por el usuario.
