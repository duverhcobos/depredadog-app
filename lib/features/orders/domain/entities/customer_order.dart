import 'package:equatable/equatable.dart';

import '../../../cart/domain/entities/cart_modifier.dart';

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
/// La personalización viaja con la MISMA estructura del ítem del
/// carrito (`CartModifier` mapea 1:1 a order_item_modifiers del
/// backend, propuesta 013): el cliente entra al pedido a verificar
/// qué quedó en cada perro — se muestra por secciones como en el
/// carrito, no como líneas de texto plano (decisión del usuario §023).
class OrderItem extends Equatable {
  const OrderItem({
    required this.productId,
    required this.productSlug,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.modifiers = const [],
    this.includedNames = const [],
  });

  final String productId;
  final String productSlug;
  final String name;
  final int quantity;
  final int unitPrice;
  final List<CartModifier> modifiers;

  /// Ingredientes que el ítem LLEVA — snapshot idéntico a
  /// `CartItem.includedNames` (§021).
  final List<String> includedNames;

  int get lineTotal => unitPrice * quantity;

  @override
  List<Object?> get props => [
    productId,
    productSlug,
    name,
    quantity,
    unitPrice,
    modifiers,
    includedNames,
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
    this.storeReference,
    this.contactPhone,
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

  /// Referencia del local para recoger ("Depredadog — Costado norte
  /// del parque principal") — solo pickup; es el dato real que
  /// reemplaza a la frase genérica "lo recoges en el local"
  /// (revisor-estetico §023).
  final String? storeReference;

  /// Celular de quién recibe (§024) — solo pedidos delivery.
  final String? contactPhone;

  /// Observación del cliente para el local (§022a).
  final String? note;
  final String? cancelReason;

  int get total => subtotal + deliveryFee;
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  /// La cancelación del cliente solo existe mientras el local no
  /// confirma (regla backend 015 — pending, decisión del usuario).
  bool get isCancellable => status == OrderStatus.received;

  /// Terminal = done o cancelled — el copy del detalle habla en
  /// pasado ("Pagaste", no "Pagas" — revisor-ui §023).
  bool get isTerminal =>
      status == OrderStatus.done || status == OrderStatus.cancelled;

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
    storeReference: storeReference,
    contactPhone: contactPhone,
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
    storeReference,
    contactPhone,
    note,
    cancelReason,
  ];
}
