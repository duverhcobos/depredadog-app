import 'package:equatable/equatable.dart';

/// SOLID (SRP/OCP): un caso por motivo de fallo de Cocina — el repository
/// impl traduce NetworkException; la UI elige el mensaje (convención
/// OrdersFailure/CheckoutFailure).
sealed class AdminFailure extends Equatable {
  const AdminFailure();

  /// Código machine-readable del backend cuando viaja — null en
  /// offline/inesperados. Unifica el switch por subtipo de la
  /// comanda §042 (revisor).
  String? get errorCode => null;

  @override
  List<Object?> get props => [];
}

/// Sin conectividad.
final class AdminOfflineFailure extends AdminFailure {
  const AdminOfflineFailure();
}

/// 4xx/5xx o inesperado — `message` se conserva para logging; la UI
/// siempre muestra su propio texto l10n. `errorCode` viaja cuando el
/// backend lo manda (§042 — TABLE_NOT_FOUND/PAYMENT_DISPATCH_FAILED/
/// INVALID_ORDER_DATA del POST /admin/orders: la comanda decide su
/// toast por código, no solo conflicto vs. resto).
final class AdminServerFailure extends AdminFailure {
  const AdminServerFailure(this.message, {this.errorCode});

  final String message;

  /// Código machine-readable del backend — null en validación sin
  /// código, 5xx genéricos y errores no-HTTP.
  @override
  final String? errorCode;

  @override
  List<Object?> get props => [message, errorCode];
}

/// 409 — conflicto de estado del backend §022: `INVALID_STATUS_TRANSITION`
/// (transición fuera de la matriz o carrera perdida — el pedido ya
/// cambió server-side), `PAYMENT_NOT_SETTLED` (el avance exigía pago
/// saldado) y `ORDER_CATALOG_VIOLATION` (un ítem de la comanda ya no
/// está vendible — §042). `errorCode` viaja para logging/telemetría Y
/// para el toast por código de la comanda nueva.
final class AdminConflictFailure extends AdminFailure {
  const AdminConflictFailure(this.errorCode);

  /// INVALID_STATUS_TRANSITION | PAYMENT_NOT_SETTLED |
  /// ORDER_CATALOG_VIOLATION | otros futuros.
  @override
  final String errorCode;

  @override
  List<Object?> get props => [errorCode];
}
