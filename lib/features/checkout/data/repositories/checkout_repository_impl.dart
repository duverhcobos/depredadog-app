import 'package:dartz/dartz.dart';

import '../../../../core/network/exceptions/network_exception.dart';
import '../../../../core/network/interfaces/i_network_info.dart';
import '../../domain/entities/checkout_store.dart';
import '../../domain/entities/saved_address.dart';
import '../../domain/failures/checkout_failure.dart';
import '../../domain/repositories/i_checkout_repository.dart';
import '../datasources/interfaces/i_checkout_remote_datasource.dart';

/// SOLID (SRP): orquesta datasource + conectividad; traduce
/// NetworkException → CheckoutFailure (la UI nunca ve excepciones
/// crudas) — mismo traductor que CatalogRepositoryImpl, con un guard
/// genérico porque son 3 llamadas con la misma forma.
class CheckoutRepositoryImpl implements ICheckoutRepository {
  const CheckoutRepositoryImpl({
    required this._remoteDataSource,
    required this._networkInfo,
  });

  final ICheckoutRemoteDataSource _remoteDataSource;
  final INetworkInfo _networkInfo;

  @override
  Future<Either<CheckoutFailure, List<SavedAddress>>> getSavedAddresses() =>
      _guard(_remoteDataSource.fetchAddresses);

  @override
  Future<Either<CheckoutFailure, CheckoutStore>> getStoreConfig() =>
      _guard(_remoteDataSource.fetchStoreConfig);

  @override
  Future<Either<CheckoutFailure, SavedAddress>> saveAddress({
    required String label,
    required String landmark,
    String? neighborhood,
    required SavedAddressType type,
  }) => _guard(
    () => _remoteDataSource.createAddress({
      'label': label,
      'landmark': landmark,
      'neighborhood': ?neighborhood,
      // El enum del backend es exactamente home|work|other (§014).
      'type': type.name,
    }),
  );

  /// Red de seguridad idéntica a la del catálogo: un 200 malformado
  /// (cast del datasource) no es NetworkException — sin el catch de
  /// respaldo la UI quedaría en loading para siempre.
  Future<Either<CheckoutFailure, T>> _guard<T>(
    Future<T> Function() call,
  ) async {
    if (!await _networkInfo.isConnected) {
      return const Left(CheckoutOfflineFailure());
    }
    try {
      return Right(await call());
    } on NetworkException catch (e) {
      return Left(_mapFailure(e));
    } catch (e) {
      return Left(CheckoutServerFailure(e.toString()));
    }
  }

  CheckoutFailure _mapFailure(NetworkException e) {
    if (e is NoConnectionException) return const CheckoutOfflineFailure();
    // 401 residual (si el refresh definitivo falló, TokenRefreshService
    // ya expulsó la sesión → el guard navega solo; esto es defensivo),
    // 4xx/5xx, timeouts → genérico con retry.
    return CheckoutServerFailure(e.message);
  }
}
