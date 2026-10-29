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

/// 400 en /auth/verify-email — código errado, expirado o cuenta que ya no
/// está pendiente (el backend da el mismo mensaje a todos — anti-enumeración).
class InvalidCodeFailure extends AuthFailure {
  const InvalidCodeFailure();
}

/// 429 — rate limit del endpoint (throttle del backend: 5/min en login y
/// verify-email, 3/min en resend-verification).
class TooManyAttemptsFailure extends AuthFailure {
  const TooManyAttemptsFailure();
}

/// 401 en /auth/me — token vencido/inválido, sesión revocada o cuenta que
/// ya no está ACTIVE (el backend no distingue — SessionNotFoundException).
/// El repositorio ya borró los tokens locales cuando emite esto.
class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure();
}

/// No hay tokens en secure storage — ni siquiera se intenta la red.
/// Resultado normal del primer arranque, no un error visible al usuario.
class NoStoredSessionFailure extends AuthFailure {
  const NoStoredSessionFailure();
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
