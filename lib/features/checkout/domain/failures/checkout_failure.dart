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

/// Motivo del rechazo del POST /orders — se resuelve del `errorCode`
/// del backend (§017/§028). `unknown` cubre código ausente (backend
/// viejo/proxy) o uno que el cliente aún no conoce.
enum OrderRejection {
  storeClosed,
  minOrderAmount,
  catalogViolation,
  invalidOrderData,
  unknown,
}

/// POST /orders rechazado por el backend (400/409 — validación o
/// regla de negocio). `message` se conserva solo para logging (llega
/// en inglés); la UI hace pattern-matching en `code` para elegir su
/// copy dedicado.
final class CheckoutOrderRejectedFailure extends CheckoutFailure {
  const CheckoutOrderRejectedFailure(this.message, {required this.code});

  final String message;
  final OrderRejection code;

  @override
  List<Object?> get props => [message, code];
}
