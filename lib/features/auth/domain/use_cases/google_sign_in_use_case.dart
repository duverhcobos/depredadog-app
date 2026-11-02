import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Google sign-in end-to-end (SDK → backend → sesión persistida).
/// Right(null) = cancel del usuario en el picker de Google.
class GoogleSignInUseCase {
  const GoogleSignInUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Either<AuthFailure, User?>> call() => _repository.signInWithGoogle();
}
