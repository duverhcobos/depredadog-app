import 'package:dartz/dartz.dart';

import '../entities/admin_day_close.dart';
import '../failures/admin_failure.dart';
import '../repositories/i_admin_repository.dart';

/// Preview del cierre (§041): GET /admin/day-close — solo lectura.
class LoadAdminDayCloseUseCase {
  const LoadAdminDayCloseUseCase(this._repository);

  final IAdminRepository _repository;

  Future<Either<AdminFailure, AdminDayClose>> call() =>
      _repository.getDayClosePreview();
}
