import 'package:equatable/equatable.dart';

/// SOLID (SRP/OCP): un caso por motivo de fallo de Cocina — el repository
/// impl traduce NetworkException; la UI elige el mensaje (convención
/// OrdersFailure/CheckoutFailure).
sealed class AdminFailure extends Equatable {
  const AdminFailure();

  @override
  List<Object?> get props => [];
}

/// Sin conectividad.
final class AdminOfflineFailure extends AdminFailure {
  const AdminOfflineFailure();
}

/// 4xx/5xx o inesperado — `message` se conserva para logging; la UI
/// siempre muestra su propio texto l10n.
final class AdminServerFailure extends AdminFailure {
  const AdminServerFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
