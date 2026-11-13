import 'package:equatable/equatable.dart';

import '../../../orders/domain/entities/customer_order.dart';

/// Canal por el que entró el pedido (espejo `order_channel` del
/// backend, §019 del backend): online = llegó por la app del cliente;
/// presencial = lo tomó el dueño en el local (POST /admin/orders).
enum AdminOrderChannel { online, presencial }

/// Método de pago en la vista del dueño (espejo `payment_method`):
/// cash = efectivo; transfer = transferencia (Nequi). `gateway` del
/// backend se mapea a transfer en la integración — la app MVP no
/// cobra por pasarela directa.
enum AdminPaymentMethod { cash, transfer }

/// Pedido en la cola del local (contrato app ↔ AdminOrderResponseDto
/// del backend §019, solo presentación por ahora — los datos viven en
/// mocks del cubit). Es la OrderResponse + lo que la vista cliente
/// oculta a propósito: `channel`, `tableLabel` y `customerName`.
///
/// SOLID (SRP): solo los campos que la card de la cola usa hoy —
/// orderNumber, contactPhone, deliveryAddress, discount, notes y
/// cancelReason llegan con el detalle del ciclo 2.
class AdminOrder extends Equatable {
  const AdminOrder({
    required this.id,
    required this.channel,
    required this.status,
    required this.items,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.total,
    required this.placedAt,
    this.tableLabel,
    this.customerName,
  });

  final String id;
  final AdminOrderChannel channel;

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

  /// Total cobrado (subtotal + deliveryFee — el DTO ya lo trae
  /// compuesto).
  final int total;
  final DateTime placedAt;

  /// Mesa del pedido presencial dine_in ("Mesa 3") — null cuando no
  /// lleva mesa.
  final String? tableLabel;

  /// Nombre del cliente registrado — null en presencial (el pedido
  /// de mostrador no tiene cuenta detrás).
  final String? customerName;

  /// Terminal = done o cancelled — cae al bucket history del
  /// listado admin (regla del use-case del backend).
  bool get isTerminal =>
      status == OrderStatus.done || status == OrderStatus.cancelled;

  @override
  List<Object?> get props => [
    id,
    channel,
    status,
    items,
    paymentMethod,
    paymentStatus,
    total,
    placedAt,
    tableLabel,
    customerName,
  ];
}
