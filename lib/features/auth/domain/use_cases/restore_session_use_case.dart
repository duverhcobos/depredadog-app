import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// SOLID (SRP): un caso de uso por acción — valida la sesión persistida al
/// abrir la app (única llamada del splash). El repositorio resuelve la
/// semántica (sin token, 401 → limpiar, offline → conservar); el caller
/// solo bifurca éxito → /home o fracaso → /login.
class RestoreSessionUseCase {
  const RestoreSessionUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Either<AuthFailure, User>> call() => _repository.restoreSession();
}
