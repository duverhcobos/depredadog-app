import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// SOLID (SRP): una acción de negocio — registro de cuenta. Hoy es un
/// passthrough al repositorio, pero es el punto de extensión para reglas
/// futuras (ej. analítica de registro, referralCode/marketingOptIn cuando
/// la UI los pida) sin tocar el cubit.
/// El éxito NO autentica: el backend deja la cuenta pending_verification
/// y el auto-login ocurre en verify-email.
class RegisterUseCase {
  const RegisterUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Either<AuthFailure, User>> call({
    required String email,
    required String password,
    required String firstName,
    String? secondName,
    required String firstLastName,
    String? secondLastName,
    String? phone,
  }) => _repository.register(
    email: email,
    password: password,
    firstName: firstName,
    secondName: secondName,
    firstLastName: firstLastName,
    secondLastName: secondLastName,
    phone: phone,
  );
}
