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
}
