import 'package:dartz/dartz.dart';

import '../entities/catalog_category.dart';
import '../failures/catalog_failure.dart';

/// SOLID (DIP): contrato del menú — la presentación no conoce HTTP.
abstract class ICatalogRepository {
  /// GET /catalog — el menú completo en un solo documento (bounded).
  Future<Either<CatalogFailure, List<CatalogCategory>>> getMenu();
}
