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

  /// Valida la sesión guardada contra el backend. Solo el splash la usa
  /// (decidir login vs home al abrir). Semántica por resultado:
  /// Right(user) = sesión válida; SessionExpiredFailure = 401, tokens ya
  /// borrados; NoStoredSessionFailure = sin token local; NoConnection/
  /// Unknown = no pudo validarse, tokens se conservan.
  Future<Either<AuthFailure, User>> restoreSession();
}
