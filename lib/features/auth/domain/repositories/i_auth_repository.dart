import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';

/// SOLID (DIP): la capa de aplicación depende de esta interfaz, nunca de
/// AuthRepositoryImpl directo (solo setup_di.dart la conoce).
abstract class IAuthRepository {
  /// Crea la cuenta (POST /auth/register). Éxito = usuario creado en
  /// estado `pending_verification` con el código ya enviado al correo —
  /// el repositorio NO persiste sesión (el endpoint no emite tokens; el
  /// auto-login ocurre en verifyEmail).
  Future<Either<AuthFailure, User>> register({
    required String email,
    required String password,
    required String firstName,
    String? secondName,
    required String firstLastName,
    String? secondLastName,
    String? phone,
  });

  /// Autentica con email/password. Si tiene éxito, el repositorio ya dejó
  /// la sesión persistida (tokens en secure storage) — el caller solo
  /// recibe el User.
  Future<Either<AuthFailure, User>> login({
    required String email,
    required String password,
  });

  /// Verifica el correo con el código de 6 dígitos. Éxito = sesión ya
  /// persistida (el backend emite IssuedSession igual que login).
  Future<Either<AuthFailure, User>> verifyEmail({
    required String email,
    required String code,
  });

  /// Reenvía el código. El backend responde 200 siempre (anti-enumeración).
  Future<Either<AuthFailure, void>> resendVerification({required String email});

  /// Pide un código de restablecimiento (POST /auth/forgot-password).
  /// Éxito = el backend aceptó el pedido (200 genérico anti-enumeración —
  /// no garantiza que el correo exista ni que el código haya salido).
  /// Sin sesión.
  Future<Either<AuthFailure, void>> forgotPassword({required String email});

  /// Chequea el código de restablecimiento SIN consumirlo
  /// (POST /auth/check-reset-code). Éxito = código vivo y NO consumido —
  /// sigue disponible para [resetPassword].
  Future<Either<AuthFailure, void>> checkResetCode({
    required String email,
    required String code,
  });

  /// Restablece la contraseña (POST /auth/reset-password). Éxito =
  /// contraseña cambiada + sesión YA persistida (el endpoint emite
  /// IssuedSession igual que verifyEmail — auto-login).
  Future<Either<AuthFailure, User>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  /// Google sign-in completo (SDK nativo → POST /auth/google). Éxito =
  /// sesión YA persistida (el endpoint emite tokens igual que login).
  /// Right(null) = el usuario canceló el selector de Google — no es error,
  /// la UI no muestra nada.
  Future<Either<AuthFailure, User?>> signInWithGoogle();

  /// Valida la sesión guardada contra el backend. Solo el splash la usa
  /// (decidir login vs home al abrir). Semántica por resultado:
  /// Right(user) = sesión válida; SessionExpiredFailure = 401, tokens ya
  /// borrados; NoStoredSessionFailure = sin token local; NoConnection/
  /// Unknown = no pudo validarse, tokens se conservan.
  Future<Either<AuthFailure, User>> restoreSession();
}
