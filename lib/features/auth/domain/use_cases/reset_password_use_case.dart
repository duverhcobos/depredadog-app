import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// SOLID (SRP): un caso de uso por operación — restablece la contraseña
/// con el código de 6 dígitos. El éxito ya deja la sesión persistida por
/// el repositorio (auto-login — el backend emite IssuedSession igual que
/// /auth/verify-email); el caller solo decide la navegación.
class ResetPasswordUseCase {
  const ResetPasswordUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Either<AuthFailure, User>> call({
    required String email,
    required String code,
    required String newPassword,
  }) => _repository.resetPassword(
    email: email,
    code: code,
    newPassword: newPassword,
  );
}
