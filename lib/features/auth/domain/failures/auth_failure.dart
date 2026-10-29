import 'package:equatable/equatable.dart';

/// SOLID (SRP/OCP): un caso por motivo de fallo de auth — el repository
/// impl es el único que traduce NetworkException → AuthFailure; la UI
/// solo hace pattern-matching para elegir el mensaje (nunca ve el texto
/// crudo del backend).
sealed class AuthFailure extends Equatable {
  const AuthFailure();

  @override
  List<Object?> get props => [];
}

/// 401 en /auth/login — mismo mensaje para email inexistente, password
/// errado o cuenta solo-Google (anti-enumeración, ya lo hace el backend).
class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure();
}

/// 403 — cuenta sin verificar el correo todavía.
class EmailNotVerifiedFailure extends AuthFailure {
  const EmailNotVerifiedFailure();
}

/// 403 — cuenta suspendida por un administrador.
class AccountSuspendedFailure extends AuthFailure {
  const AccountSuspendedFailure();
}

/// 429 — rate limit del endpoint (5 req/min en el backend).
class TooManyAttemptsFailure extends AuthFailure {
  const TooManyAttemptsFailure();
}

/// Sin conectividad (INetworkInfo o timeout de conexión).
class NoConnectionFailure extends AuthFailure {
  const NoConnectionFailure();
}

/// Cualquier otro error no mapeado — conserva el mensaje del backend solo
/// para logging/depuración, la UI muestra un texto genérico propio.
class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
