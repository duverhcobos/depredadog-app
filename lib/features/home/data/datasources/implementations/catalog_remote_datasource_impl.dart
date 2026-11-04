import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../models/catalog_models.dart';
import '../interfaces/i_catalog_remote_datasource.dart';

/// SOLID (SRP): solo llama GET /catalog y parsea — el Bearer lo pone el
/// AuthInterceptor, los errores los traduce el repository.
class CatalogRemoteDataSourceImpl implements ICatalogRemoteDataSource {
  const CatalogRemoteDataSourceImpl({required this._networkService});

  final INetworkService _networkService;

  @override
  Future<List<CatalogCategoryModel>> fetchMenu() async {
    final response = await _networkService.get('/catalog');
    final categories =
        (response as Map<String, dynamic>)['categories'] as List<dynamic>;
    return categories
        .map((c) => CatalogCategoryModel.fromJson(c as Map<String, dynamic>))
        .toList();
  }
}
