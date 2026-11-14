import 'package:equatable/equatable.dart';

import '../../../orders/domain/entities/customer_order.dart';

/// Canal por el que entró el pedido (espejo `order_channel` del
/// backend, §019 del backend): online = llegó por la app del cliente;
/// presencial = lo tomó el dueño en el local (POST /admin/orders).
enum AdminOrderChannel { online, presencial }

/// Método de pago en la vista del dueño (espejo `payment_method`):
/// cash = efectivo; transfer = transferencia manual (el dueño la
/// verifica en su Nequi y la registra con "Registrar pago");
/// nequi = cobro DENTRO de la app (Nequi push/pasarela) — el
/// webhook del backend es quien confirma: mientras no llegue,
/// ni "Registrar pago" ni "Confirmar" existen (decisión §036 —
/// el cobro automático no se adelanta a mano).
enum AdminPaymentMethod { cash, transfer, nequi }

/// Tipo de servicio del pedido (espejo `order_service_type` —
/// incluye dine_in que el enum del cliente no tiene porque el
/// cliente nunca pide a mesa; solo lo crea el dueño). Define el
/// label del paso `ready` en la matriz de acciones.
enum AdminServiceType { pickup, delivery, dineIn }

/// Pedido en la cola del local (contrato app ↔ AdminOrderResponseDto
/// del backend §019, solo presentación por ahora — los datos viven en
/// mocks del cubit). Es la OrderResponse + lo que la vista cliente
/// oculta a propósito: `channel`, `tableLabel` y `customerName`.
///
/// SOLID (SRP): solo los campos que la cola y el detalle usan hoy.
class AdminOrder extends Equatable {
  const AdminOrder({
    required this.id,
    required this.channel,
    required this.serviceType,
    required this.status,
    required this.items,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotal,
    required this.deliveryFee,
    required this.placedAt,
    this.tableLabel,
    this.customerName,
    this.cancelReason,
    this.addressLabel,
    this.landmark,
    this.neighborhood,
    this.hasLocationPin = false,
    this.contactPhone,
    this.note,
    this.locationLat,
    this.locationLng,
    this.locationUrl,
    this.statusChangedAt,
  });

  final String id;
  final AdminOrderChannel channel;

  /// Servicio (espejo `service_type` del backend §022) — define la
  /// etiqueta del paso `ready`: delivery "Va en camino", dineIn
  /// "Servir", pickup "Listo p/recoger".
  final AdminServiceType serviceType;

  /// Estado vivo del pedido (mismo enum del cliente — espejo
  /// `order_status`): received = pending del backend, que el dueño
  /// lee como "Pendiente" de confirmar.
  final OrderStatus status;

  /// Ítems cobrados — el MISMO snapshot OrderItem del cliente (1:1
  /// OrderItemResponseDto): la cola solo usa name+quantity del
  /// resumen.
  final List<OrderItem> items;
  final AdminPaymentMethod paymentMethod;
  final OrderPaymentStatus paymentStatus;

  /// Subtotal de ítems y domicilio — el DTO los trae separados
  /// (OrderResponse del backend §015). El desglose los muestra.
  final int subtotal;
  final int deliveryFee;

  /// Total cobrado = subtotal + domicilio (misma regla del
  /// CustomerOrder).
  int get total => subtotal + deliveryFee;
  final DateTime placedAt;

  /// Mesa del pedido presencial dine_in ("Mesa 3") — null cuando no
  /// lleva mesa.
  final String? tableLabel;

  /// Nombre del cliente registrado — null en presencial (el pedido
  /// de mostrador no tiene cuenta detrás).
  final String? customerName;

  /// Motivo de la cancelación — el PATCH status del backend ya lo
  /// acepta (§019); null cuando no se canceló o se canceló sin nota.
  final String? cancelReason;

  /// Bloque de entrega (solo delivery — null en pickup/dineIn):
  /// etiqueta de la dirección ("Casa"), punto de referencia (la zona
  /// no tiene direcciones formales), barrio, pin de Maps adjunto y
  /// celular de quién recibe (§024).
  final String? addressLabel;
  final String? landmark;
  final String? neighborhood;
  final bool hasLocationPin;
  final String? contactPhone;

  /// Observación libre del cliente ("sin picante, es para el niño").
  final String? note;

  /// Coordenadas del pin que el cliente fijó en Maps (espejo
  /// `addresses.latitude/longitude` del backend) — solo cuando
  /// hasLocationPin: el tap abre Maps con el punto y el ícono
  /// copia el enlace (§037).
  final double? locationLat;
  final double? locationLng;

  /// Enlace compartido de Maps que el cliente guardó al fijar el
  /// pin ("https://maps.app.goo.gl/…") — si existe es el enlace
  /// canónico: el tap lo abre y el ícono lo copia verbatim, en vez
  /// de reconstruirlo desde lat/lng (§037 — decisión del dueño).
  final String? locationUrl;

  /// Cuándo entró al estado/carril actual — la cola del carril se
  /// ordena por este reloj (recién movido cae al fondo), no por
  /// placedAt (§037 — decisión del dueño: cola por carril). Null =
  /// nació en el estado actual (entró al carril en placedAt).
  final DateTime? statusChangedAt;

  /// Terminal = done o cancelled — sin más pasos de avance; el
  /// done sigue vivo en la cola (carril Entregado) hasta el cierre
  /// de caja, solo el cancelled cruza al historial de una (§036).
  bool get isTerminal =>
      status == OrderStatus.done || status == OrderStatus.cancelled;

  /// Cobro Nequi en verificación (§036): el pedido pagó por la app
  /// pero el webhook aún no reporta paid — pending = esperando,
  /// failed = el webhook ya dijo que no (solo queda cancelar). En
  /// ambos casos NO hay acción de avance ni cobro manual: nadie
  /// adelanta lo que solo el webhook puede confirmar.
  bool get awaitsWebhook =>
      paymentMethod == AdminPaymentMethod.nequi &&
      paymentStatus != OrderPaymentStatus.paid;

  /// Mutación inmutable para las operaciones mock del cubit (§035 —
  /// advance/markPaid/cancel reconstruyen la entidad).
  AdminOrder copyWith({
    OrderStatus? status,
    OrderPaymentStatus? paymentStatus,
    String? cancelReason,
  }) => AdminOrder(
    id: id,
    channel: channel,
    serviceType: serviceType,
    status: status ?? this.status,
    statusChangedAt: status != null && status != this.status
        ? DateTime.now()
        : statusChangedAt,
    items: items,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    subtotal: subtotal,
    deliveryFee: deliveryFee,
    placedAt: placedAt,
    tableLabel: tableLabel,
    customerName: customerName,
    cancelReason: cancelReason ?? this.cancelReason,
    addressLabel: addressLabel,
    landmark: landmark,
    neighborhood: neighborhood,
    hasLocationPin: hasLocationPin,
    contactPhone: contactPhone,
    note: note,
    locationLat: locationLat,
    locationLng: locationLng,
    locationUrl: locationUrl,
  );

  @override
  List<Object?> get props => [
    id,
    channel,
    serviceType,
    status,
    items,
    paymentMethod,
    paymentStatus,
    subtotal,
    deliveryFee,
    placedAt,
    tableLabel,
    customerName,
    cancelReason,
    addressLabel,
    landmark,
    neighborhood,
    hasLocationPin,
    contactPhone,
    note,
    locationLat,
    locationLng,
    locationUrl,
    statusChangedAt,
  ];
}
