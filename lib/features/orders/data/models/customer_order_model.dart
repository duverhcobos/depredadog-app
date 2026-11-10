import '../../../cart/domain/entities/cart_modifier.dart';
import '../../domain/entities/customer_order.dart';

/// Parser del OrderResponseDto (§015/016) → CustomerOrder. Los
/// mapeos: status pending→received · transfer→nequi · cash→onDelivery
/// · payment null→pending defensivo · deliveryAddress→landmark ·
/// modifierGroup slug→enum con las mismas reglas del detalle del
/// producto · NULL legacy → degradación documentada.
class CustomerOrderModel extends CustomerOrder {
  const CustomerOrderModel({
    required super.id,
    required super.serviceType,
    required super.status,
    required super.items,
    required super.paymentMethod,
    required super.paymentStatus,
    required super.subtotal,
    required super.deliveryFee,
    required super.placedAt,
    super.landmark,
    super.hasLocationPin,
    super.contactPhone,
    super.note,
    super.cancelReason,
  }) : super(addressLabel: null, neighborhood: null, storeReference: null);

  factory CustomerOrderModel.fromJson(Map<String, dynamic> json) {
    final payment = json['payment'] as Map<String, dynamic>?;
    return CustomerOrderModel(
      id: json['id'] as String,
      serviceType: json['serviceType'] == 'delivery'
          ? OrderServiceType.delivery
          : OrderServiceType.pickup,
      status: switch (json['status'] as String) {
        'pending' => OrderStatus.received,
        'confirmed' => OrderStatus.confirmed,
        'preparing' => OrderStatus.preparing,
        'done' => OrderStatus.done,
        'cancelled' => OrderStatus.cancelled,
        // Un status nuevo del backend es un pedido VIVO, no un
        // cancelado — nunca cae a terminal por desconocido
        // (revisor §027).
        _ => OrderStatus.received,
      },
      items: [
        for (final i in json['items'] as List<dynamic>)
          OrderItem(
            productId: (i as Map<String, dynamic>)['productId'] as String,
            // §016 — null en filas viejas → '' → fallback de marca.
            productSlug: i['productSlug'] as String? ?? '',
            name: i['productName'] as String,
            quantity: i['quantity'] as int,
            unitPrice: i['unitPrice'] as int,
            includedNames: [
              for (final n in (i['includedNames'] as List<dynamic>? ?? []))
                n as String,
            ],
            modifiers: [
              for (final m in (i['modifiers'] as List<dynamic>? ?? []))
                _modifierFromJson(m as Map<String, dynamic>),
            ],
          ),
      ],
      paymentMethod: payment?['method'] == 'cash'
          ? OrderPaymentMethod.onDelivery
          : OrderPaymentMethod.nequi,
      paymentStatus: switch (payment?['status'] as String?) {
        'paid' => OrderPaymentStatus.paid,
        'failed' => OrderPaymentStatus.failed,
        _ => OrderPaymentStatus.pending,
      },
      subtotal: json['subtotal'] as int,
      deliveryFee: json['deliveryFee'] as int,
      placedAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      landmark: json['deliveryAddress'] as String?,
      hasLocationPin: json['deliveryLocationLink'] != null,
      contactPhone: json['contactPhone'] as String?,
      note: json['notes'] as String?,
      cancelReason: json['cancelReason'] as String?,
    );
  }

  /// Fila de modifier — el group sale del slug del snapshot §016 con
  /// la misma asignación del detalle del producto: removed y la fila
  /// del reemplazo siempre `ingredient`; added por slug; null legacy
  /// → `extra` (fallback documentado del enum).
  static CartModifier _modifierFromJson(Map<String, dynamic> m) {
    final action = m['action'] == 'added'
        ? CartModifierAction.added
        : CartModifierAction.removed;
    final replaces = m['replacesOptionId'] as String?;
    final groupSlug = m['modifierGroup'] as String?;
    final group = action == CartModifierAction.removed || replaces != null
        ? CartModifierGroup.ingredient
        : switch (groupSlug) {
            'toppings' => CartModifierGroup.topping,
            'sauces' => CartModifierGroup.sauce,
            _ => CartModifierGroup.extra,
          };
    return CartModifier(
      optionId: m['optionId'] as String? ?? '',
      optionName: m['optionName'] as String,
      action: action,
      priceDelta: m['priceDelta'] as int,
      replacesOptionId: replaces,
      group: group,
    );
  }
}
