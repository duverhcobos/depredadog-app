import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../cart/domain/entities/cart_modifier.dart';
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
      includedNames: [
        'Pan brioche',
        'Salchicha americana',
        'Papas a la francesa',
        'Cebolla grillada',
      ],
      modifiers: [
        CartModifier(
          optionId: 'opt-mozz',
          optionName: 'Queso mozzarella',
          action: CartModifierAction.removed,
          priceDelta: 0,
          group: CartModifierGroup.ingredient,
        ),
        CartModifier(
          optionId: 'opt-salami',
          optionName: 'Salami',
          action: CartModifierAction.added,
          priceDelta: 3000,
          group: CartModifierGroup.extra,
        ),
        CartModifier(
          optionId: 'opt-maiz',
          optionName: 'Maíz tierno',
          action: CartModifierAction.added,
          priceDelta: 0,
          group: CartModifierGroup.topping,
        ),
        CartModifier(
          optionId: 'opt-rosada',
          optionName: 'Salsa rosada',
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
        'Pan brioche',
        'Salchicha americana',
        'Tocineta',
        'Huevo de codorniz',
      ],
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
  contactPhone: '3001234567',
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
      includedNames: [
        'Pan brioche',
        'Salchicha americana',
        'Tocineta',
        'Champiñones',
      ],
      modifiers: [
        CartModifier(
          optionId: 'opt-tocineta',
          optionName: 'Tocineta crocante',
          action: CartModifierAction.added,
          priceDelta: 4000,
          group: CartModifierGroup.extra,
        ),
      ],
    ),
  ],
  paymentMethod: OrderPaymentMethod.nequi,
  paymentStatus: OrderPaymentStatus.pending,
  subtotal: 25000,
  deliveryFee: 0,
  placedAt: DateTime(2026, 11, 8, 13, 10),
  statusChangedAt: DateTime(2026, 11, 8, 13, 10),
  storeReference: 'Depredadog — Costado norte del parque principal',
);

/// Domicilio "Confirmado" pagando en efectivo contra entrega — la
/// única vía donde existe efectivo (el local es prepago, §022c).
final kMockOrderDeliveryCash = CustomerOrder(
  id: 'ord-6',
  serviceType: OrderServiceType.delivery,
  status: OrderStatus.confirmed,
  items: const [
    OrderItem(
      productId: 'p-ave',
      productSlug: 'ave-de-presa',
      name: 'Ave de Presa',
      quantity: 1,
      unitPrice: 18000,
      includedNames: ['Pan brioche', 'Pechuga apanada', 'Queso', 'Lechuga'],
      modifiers: [
        CartModifier(
          optionId: 'opt-salsa-casa',
          optionName: 'Salsa de la casa',
          action: CartModifierAction.removed,
          priceDelta: 0,
          group: CartModifierGroup.ingredient,
        ),
      ],
    ),
  ],
  paymentMethod: OrderPaymentMethod.onDelivery,
  paymentStatus: OrderPaymentStatus.pending,
  subtotal: 18000,
  deliveryFee: 0,
  placedAt: DateTime(2026, 11, 8, 13, 45),
  statusChangedAt: DateTime(2026, 11, 8, 13, 50),
  addressLabel: 'Casa de mi mamá',
  landmark: 'Portón negro frente a la tienda',
  neighborhood: 'Vereda El Carmen',
  // §024 — recibe otra persona (el celular de la mamá): se ve que no
  // es el de la cuenta.
  contactPhone: '3109876543',
  note: 'Traer cambio de 20',
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
        includedNames: [
          'Pan brioche',
          'Salchicha americana',
          'Queso mozzarella',
        ],
        modifiers: [
          CartModifier(
            optionId: 'opt-huevo',
            optionName: 'Huevo de codorniz',
            action: CartModifierAction.removed,
            priceDelta: 0,
            group: CartModifierGroup.ingredient,
          ),
        ],
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
        includedNames: [
          'Pan brioche',
          'Salchicha americana',
          'Papas a la francesa',
        ],
      ),
    ],
    paymentMethod: OrderPaymentMethod.nequi,
    paymentStatus: OrderPaymentStatus.paid,
    subtotal: 14000,
    deliveryFee: 0,
    placedAt: DateTime(2026, 11, 4, 20, 15),
    statusChangedAt: DateTime(2026, 11, 4, 20, 40),
    storeReference: 'Depredadog — Costado norte del parque principal',
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
        includedNames: ['Pan brioche', 'Pechuga apanada', 'Queso', 'Lechuga'],
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
/// SINGLETON como CartCubit: el tab y su detalle /orders/:id
/// comparten la misma instancia (revisor-ui §023).
class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({
    List<CustomerOrder>? seedActive,
    List<CustomerOrder>? seedHistory,
  }) : super(
         OrdersState(
           active:
               seedActive ??
               [kMockOrderDelivery, kMockOrderPickup, kMockOrderDeliveryCash],
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
