import 'package:equatable/equatable.dart';

/// SOLID (SRP/OCP): un caso por motivo de fallo del checkout — el
/// repository impl es el único que traduce NetworkException; la UI solo
/// hace pattern-matching para elegir el mensaje (misma convención que
/// CatalogFailure).
sealed class CheckoutFailure extends Equatable {
  const CheckoutFailure();

  @override
  List<Object?> get props => [];
}

/// Sin conectividad (INetworkInfo o timeout de conexión).
final class CheckoutOfflineFailure extends CheckoutFailure {
  const CheckoutOfflineFailure();
}

/// Cualquier otro error (4xx/5xx, timeout, parseo, inesperado) —
/// conserva el mensaje solo para logging; la UI muestra texto genérico
/// propio.
final class CheckoutServerFailure extends CheckoutFailure {
  const CheckoutServerFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// POST /orders rechazado por el backend (400/409 — validación o
/// regla de negocio: local cerrado, producto agotado, reemplazo
/// inválido). `message` es el texto del servidor — ya viene en
/// español producto y la UI lo muestra tal cual.
final class CheckoutOrderRejectedFailure extends CheckoutFailure {
  const CheckoutOrderRejectedFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
