import 'package:dartz/dartz.dart';

import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// SOLID (SRP): un caso de uso por operación — pide el código de
/// restablecimiento. El backend responde 200 siempre que el body valide
/// (anti-enumeración — silencio si el correo no existe o la cuenta está
/// suspendida); los errores esperados son 429 y de red — cualquier otro
/// cae al Unknown genérico del repositorio.
class ForgotPasswordUseCase {
  const ForgotPasswordUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Either<AuthFailure, void>> call({required String email}) =>
      _repository.forgotPassword(email: email);
}
