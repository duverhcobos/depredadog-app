import 'package:dartz/dartz.dart';

import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// SOLID (SRP): un caso de uso por operación — chequea el código de
/// restablecimiento SIN consumirlo (queda vivo para el reset del paso 3).
/// Éxito = el código existe, no está consumido ni expirado; el 400
/// "Invalid or expired code" llega como InvalidCodeFailure.
class CheckResetCodeUseCase {
  const CheckResetCodeUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Either<AuthFailure, void>> call({
    required String email,
    required String code,
  }) => _repository.checkResetCode(email: email, code: code);
}
