import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// SOLID (SRP): un caso de uso por operación — verifica el correo con el
/// código de 6 dígitos. El éxito ya deja la sesión persistida por el
/// repositorio (auto-login — el backend emite IssuedSession igual que
/// /auth/login); el caller solo decide la navegación.
class VerifyEmailUseCase {
  const VerifyEmailUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Either<AuthFailure, User>> call({
    required String email,
    required String code,
  }) => _repository.verifyEmail(email: email, code: code);
}
