import 'package:dartz/dartz.dart';

import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// SOLID (SRP): reenvía el código de verificación. El backend responde 200
/// siempre que el body valide (anti-enumeración — silencio si el correo no
/// existe o ya está verificado); los errores esperados son 429 y de red —
/// cualquier otro cae al Unknown genérico del repositorio.
class ResendVerificationUseCase {
  const ResendVerificationUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Either<AuthFailure, void>> call({required String email}) =>
      _repository.resendVerification(email: email);
}
