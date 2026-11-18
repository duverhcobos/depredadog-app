import 'package:dartz/dartz.dart';

import '../entities/admin_day_close.dart';
import '../failures/admin_failure.dart';
import '../repositories/i_admin_repository.dart';

/// Cierre del periodo (§041): POST /admin/day-close — atómico.
class CloseAdminDayUseCase {
  const CloseAdminDayUseCase(this._repository);

  final IAdminRepository _repository;

  Future<Either<AdminFailure, AdminDayClose>> call() =>
      _repository.closeDay();
}
