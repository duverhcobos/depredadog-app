import 'package:dartz/dartz.dart';

import '../../../../core/network/exceptions/network_exception.dart';
import '../../../../core/network/interfaces/i_network_info.dart';
import '../../domain/entities/checkout_store.dart';
import '../../domain/entities/placed_order.dart';
import '../../domain/entities/saved_address.dart';
import '../../domain/failures/checkout_failure.dart';
import '../../domain/repositories/i_checkout_repository.dart';
import '../../domain/use_cases/create_order_params.dart';
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

  @override
  Future<Either<CheckoutFailure, PlacedOrder>> createOrder(
    CreateOrderParams params,
  ) => _guard(
    () => _remoteDataSource.createOrder({
      'serviceType': params.serviceType,
      'items': [
        for (final item in params.items)
          {
            'productId': item.productId,
            'quantity': item.quantity,
            'modifiers': [
              for (final m in item.modifiers)
                {
                  'optionId': m.optionId,
                  'action': m.action,
                  if (m.replacesOptionId != null)
                    'replacesOptionId': m.replacesOptionId,
                },
            ],
          },
      ],
      'paymentMethod': params.paymentMethod,
      'clientRequestId': params.clientRequestId,
      if (params.addressId != null) 'addressId': params.addressId,
      if (params.newLandmark != null)
        'newAddress': {
          'landmark': params.newLandmark,
          if (params.newNeighborhood != null)
            'neighborhood': params.newNeighborhood,
        },
      if (params.contactPhone != null) 'contactPhone': params.contactPhone,
      if (params.deliveryLocationLink != null)
        'deliveryLocationLink': params.deliveryLocationLink,
      if (params.payerPhone != null) 'payerPhone': params.payerPhone,
      if (params.notes != null) 'notes': params.notes,
    }),
    mapFailure: _mapOrderFailure,
  );

  /// POST /orders distingue el rechazo de negocio tipado por
  /// `errorCode` (§028 — `message` llega en inglés, solo logging) de
  /// la falla de infraestructura (→ genérico con retry). Solo
  /// 400/409/422 de un ServerException califican: el 401 residual
  /// dice 'Unauthorized' y un 4xx sin body dice 'Request failed' —
  /// inglés crudo que no debe llegar a la fila inline.
  CheckoutFailure _mapOrderFailure(NetworkException e) {
    if (e is NoConnectionException) return const CheckoutOfflineFailure();
    if (e is ServerException && const {400, 409, 422}.contains(e.statusCode)) {
      return CheckoutOrderRejectedFailure(
        e.message,
        code: _parseRejection(e.errorCode),
      );
    }
    return CheckoutServerFailure(e.message);
  }

  /// Red de seguridad idéntica a la del catálogo: un 200 malformado
  /// (cast del datasource) no es NetworkException — sin el catch de
  /// respaldo la UI quedaría en loading para siempre.
  Future<Either<CheckoutFailure, T>> _guard<T>(
    Future<T> Function() call, {
    CheckoutFailure Function(NetworkException)? mapFailure,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(CheckoutOfflineFailure());
    }
    try {
      return Right(await call());
    } on NetworkException catch (e) {
      return Left((mapFailure ?? _mapFailure)(e));
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

  /// `errorCode` del backend (§017) → motivo tipado. Código ausente o
  /// desconocido → `unknown` (el copy genérico sigue sirviendo).
  OrderRejection _parseRejection(String? errorCode) {
    return switch (errorCode) {
      'STORE_CLOSED' => OrderRejection.storeClosed,
      'MIN_ORDER_AMOUNT' => OrderRejection.minOrderAmount,
      'ORDER_CATALOG_VIOLATION' => OrderRejection.catalogViolation,
      'INVALID_ORDER_DATA' => OrderRejection.invalidOrderData,
      _ => OrderRejection.unknown,
    };
  }
}
