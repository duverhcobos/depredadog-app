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
/// siempre muestra su propio texto l10n.
final class OrdersServerFailure extends OrdersFailure {
  const OrdersServerFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// POST /orders/:id/cancel rechazado (409 ORDER_NOT_CANCELLABLE — ya
/// no está pending). `message` llega en inglés y solo sirve para
/// logging; la UI muestra su copy dedicado (§027/§028).
final class OrdersCancelRejectedFailure extends OrdersFailure {
  const OrdersCancelRejectedFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
