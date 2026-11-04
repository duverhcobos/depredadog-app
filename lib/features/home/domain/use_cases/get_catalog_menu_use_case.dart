import 'package:dartz/dartz.dart';

import '../entities/catalog_category.dart';
import '../failures/catalog_failure.dart';
import '../repositories/i_catalog_repository.dart';

/// SOLID (SRP): una acción — traer el menú completo.
class GetCatalogMenuUseCase {
  const GetCatalogMenuUseCase(this._repository);

  final ICatalogRepository _repository;

  Future<Either<CatalogFailure, List<CatalogCategory>>> call() =>
      _repository.getMenu();
}
