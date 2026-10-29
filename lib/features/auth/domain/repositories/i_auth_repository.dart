import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';

/// SOLID (DIP): la capa de aplicación depende de esta interfaz, nunca de
/// AuthRepositoryImpl directo (solo setup_di.dart la conoce).
abstract class IAuthRepository {
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
}
