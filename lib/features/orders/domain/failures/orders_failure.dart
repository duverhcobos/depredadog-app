import 'package:equatable/equatable.dart';

/// SOLID (SRP/OCP): un caso por motivo de fallo de Pedidos — el
/// repository impl traduce NetworkException; la UI elige el mensaje
/// (misma convención de CheckoutFailure/CatalogFailure).
sealed class OrdersFailure extends Equatable {
  const OrdersFailure();

  @override
  List<Object?> get props => [];
}

/// Sin conectividad.
final class OrdersOfflineFailure extends OrdersFailure {
  const OrdersOfflineFailure();
}

/// 4xx/5xx o inesperado — `message` se conserva para logging; la UI
/// muestra su propio texto salvo en el rechazo de cancelar.
final class OrdersServerFailure extends OrdersFailure {
  const OrdersServerFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// POST /orders/:id/cancel rechazado (409 — ya no está pending; el
/// mensaje del servidor viene en español y se muestra tal cual).
final class OrdersCancelRejectedFailure extends OrdersFailure {
  const OrdersCancelRejectedFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
