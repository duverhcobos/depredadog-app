import '../../domain/entities/customer_order.dart';
import 'order_item_modifier_mapper.dart';

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
        'ready' => OrderStatus.ready,
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
                cartModifierFromOrderJson(m as Map<String, dynamic>),
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
}
