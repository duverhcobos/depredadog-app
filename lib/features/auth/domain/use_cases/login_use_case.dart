import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// SOLID (SRP): una acción de negocio — login. Hoy es un passthrough al
/// repositorio, pero es el punto de extensión para reglas futuras (ej.
/// analítica de login, lockout local tras N fallos) sin tocar el cubit.
class LoginUseCase {
  const LoginUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Either<AuthFailure, User>> call({
    required String email,
    required String password,
  }) => _repository.login(email: email, password: password);
}
