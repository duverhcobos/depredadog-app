import 'package:dartz/dartz.dart';

import '../../../../core/network/exceptions/network_exception.dart';
import '../../../../core/network/interfaces/i_network_info.dart';
import '../../domain/entities/catalog_category.dart';
import '../../domain/failures/catalog_failure.dart';
import '../../domain/repositories/i_catalog_repository.dart';
import '../datasources/interfaces/i_catalog_remote_datasource.dart';

/// SOLID (SRP): orquesta datasource + conectividad; traduce
/// NetworkException → CatalogFailure (la UI nunca ve excepciones crudas).
class CatalogRepositoryImpl implements ICatalogRepository {
  const CatalogRepositoryImpl({
    required this._remoteDataSource,
    required this._networkInfo,
  });

  final ICatalogRemoteDataSource _remoteDataSource;
  final INetworkInfo _networkInfo;

  @override
  Future<Either<CatalogFailure, List<CatalogCategory>>> getMenu() async {
    if (!await _networkInfo.isConnected) {
      return const Left(CatalogOfflineFailure());
    }
    try {
      final menu = await _remoteDataSource.fetchMenu();
      return Right(menu);
    } on NetworkException catch (e) {
      return Left(_mapFailure(e));
    } catch (e) {
      // Red de seguridad (misma que auth): un 200 malformado (cast del
      // datasource) no es NetworkException — sin este catch la UI
      // quedaría en loading para siempre.
      return Left(CatalogServerFailure(e.toString()));
    }
  }

  CatalogFailure _mapFailure(NetworkException e) {
    if (e is NoConnectionException) return const CatalogOfflineFailure();
    // 401 residual (si el refresh definitivo falló, TokenRefreshService
    // ya expulsó la sesión → el guard navega solo; esto es defensivo),
    // 429, 5xx, timeouts → genérico con retry.
    return CatalogServerFailure(e.message);
  }
}
