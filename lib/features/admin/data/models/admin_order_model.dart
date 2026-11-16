import '../../../orders/data/models/order_item_modifier_mapper.dart';
import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_order.dart';

/// Parser del AdminOrderResponseDto (backend §019 + §022/§037) → AdminOrder.
/// Misma convención de CustomerOrderModel — mapeos:
/// · status 'pending'→received; un status desconocido NUNCA cae a terminal
///   (fallback received, revisor §027).
/// · serviceType 'dine_in'→dineIn (solo existe en pedidos del local).
/// · channel 'presencial'→presencial (lo tomó el dueño); else online.
/// · payment NULL (pedidos viejos sin fila de pago) → cash + pending
///   defensivo — la puerta de pago de Cocina lo trata como "sin cobrar".
/// · Dirección desglosada (§037.B): deliveryAddressLabel/Landmark/
///   Neighborhood; cuando no hay ficha de dirección (pedidos por teléfono
///   sin addressId) el landmark cae al snapshot crudo `deliveryAddress`
///   ("punto de referencia (barrio)") — mismo fallback del DTO.
/// · deliveryLocationLink → locationUrl: el pin canónico (§037) — la app
///   NUNCA reconstruye el link cuando el backend lo trae; hasLocationPin
///   = link != null (lat/lng no viajan en el DTO admin).
/// · statusChangedAt → el reloj de la cola por carril (§037.A).
class AdminOrderModel extends AdminOrder {
  const AdminOrderModel({
    required super.id,
    super.orderNumber,
    required super.channel,
    required super.serviceType,
    required super.status,
    required super.items,
    required super.paymentMethod,
    required super.paymentStatus,
    required super.subtotal,
    required super.deliveryFee,
    required super.placedAt,
    super.statusChangedAt,
    super.tableLabel,
    super.customerName,
    super.cancelReason,
    super.addressLabel,
    super.landmark,
    super.neighborhood,
    super.hasLocationPin,
    super.contactPhone,
    super.note,
    super.locationUrl,
  });

  factory AdminOrderModel.fromJson(Map<String, dynamic> json) {
    final payment = json['payment'] as Map<String, dynamic>?;
    final link = json['deliveryLocationLink'] as String?;
    // Fallback §037.B: sin ficha de dirección, el snapshot crudo hace
    // de landmark ("Casa blanca frente a la cancha (Barrio Centro)").
    final landmark =
        json['deliveryLandmark'] as String? ?? json['deliveryAddress'] as String?;
    final statusChangedAt = json['statusChangedAt'] as String?;
    return AdminOrderModel(
      id: json['id'] as String,
      orderNumber: json['orderNumber'] as int?,
      channel: json['channel'] == 'presencial'
          ? AdminOrderChannel.presencial
          : AdminOrderChannel.online,
      serviceType: switch (json['serviceType'] as String) {
        'delivery' => AdminServiceType.delivery,
        'dine_in' => AdminServiceType.dineIn,
        _ => AdminServiceType.pickup,
      },
      status: switch (json['status'] as String) {
        'pending' => OrderStatus.received,
        'confirmed' => OrderStatus.confirmed,
        'preparing' => OrderStatus.preparing,
        'ready' => OrderStatus.ready,
        'done' => OrderStatus.done,
        'cancelled' => OrderStatus.cancelled,
        _ => OrderStatus.received,
      },
      items: [
        for (final i in json['items'] as List<dynamic>)
          OrderItem(
            productId: (i as Map<String, dynamic>)['productId'] as String,
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
      paymentMethod: switch (payment?['method'] as String?) {
        'transfer' => AdminPaymentMethod.transfer,
        // El enum backend es cash|transfer|gateway — Nequi llega como
        // 'gateway' con provider='nequi' (§038 — verificado contra el
        // DTO real); 'nequi' por compat con fixtures viejas.
        'gateway' || 'nequi' => AdminPaymentMethod.nequi,
        _ => AdminPaymentMethod.cash, // 'cash' + null legacy defensivo
      },
      paymentStatus: switch (payment?['status'] as String?) {
        'paid' => OrderPaymentStatus.paid,
        'failed' => OrderPaymentStatus.failed,
        _ => OrderPaymentStatus.pending,
      },
      subtotal: json['subtotal'] as int,
      deliveryFee: json['deliveryFee'] as int,
      placedAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      statusChangedAt: statusChangedAt == null
          ? null
          : DateTime.parse(statusChangedAt).toLocal(),
      tableLabel: json['tableLabel'] as String?,
      customerName: json['customerName'] as String?,
      cancelReason: json['cancelReason'] as String?,
      addressLabel: json['deliveryAddressLabel'] as String?,
      landmark: landmark,
      neighborhood: json['deliveryNeighborhood'] as String?,
      hasLocationPin: link != null,
      contactPhone: json['contactPhone'] as String?,
      note: json['notes'] as String?,
      locationUrl: link,
    );
  }
}
