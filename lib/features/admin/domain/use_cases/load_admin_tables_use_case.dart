import 'package:dartz/dartz.dart';

import '../entities/admin_table.dart';
import '../failures/admin_failure.dart';
import '../repositories/i_admin_repository.dart';

/// SOLID (SRP): una acción — traer las mesas con ocupación en vivo
/// (GET /admin/tables — §042, picker de la comanda).
class LoadAdminTablesUseCase {
  const LoadAdminTablesUseCase(this._repository);

  final IAdminRepository _repository;

  Future<Either<AdminFailure, List<AdminTable>>> call() =>
      _repository.getTables();
}
