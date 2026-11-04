import '../../models/catalog_models.dart';

/// SOLID (DIP): puerto HTTP del catálogo — devuelve models o lanza
/// NetworkException; los callers nunca ven Dio.
abstract class ICatalogRemoteDataSource {
  /// GET /catalog — Bearer lo adjunta el AuthInterceptor.
  Future<List<CatalogCategoryModel>> fetchMenu();
}
