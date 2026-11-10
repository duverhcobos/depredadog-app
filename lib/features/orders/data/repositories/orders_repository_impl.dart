import 'package:dartz/dartz.dart';

import '../../../../core/network/exceptions/network_exception.dart';
import '../../../../core/network/interfaces/i_network_info.dart';
import '../../domain/entities/customer_order.dart';
import '../../domain/failures/orders_failure.dart';
import '../../domain/repositories/i_orders_repository.dart';
import '../datasources/interfaces/i_orders_remote_datasource.dart';

/// SOLID (SRP): orquesta datasource + conectividad; traduce
/// NetworkException → OrdersFailure (la UI nunca ve excepciones
/// crudas) — mismo `_guard` genérico de CheckoutRepositoryImpl; el
/// cancel lleva mapper propio (409/ORDER_NOT_CANCELLABLE →
/// CancelRejected, §028).
class OrdersRepositoryImpl implements IOrdersRepository {
  const OrdersRepositoryImpl({
    required this._remoteDataSource,
    required this._networkInfo,
  });

  final IOrdersRemoteDataSource _remoteDataSource;
  final INetworkInfo _networkInfo;

  @override
  Future<Either<OrdersFailure, List<CustomerOrder>>> getActiveOrders() =>
      _guard(
        () async => (await _remoteDataSource.fetchOrdersPage('active')).items,
      );

  @override
  Future<Either<OrdersFailure, OrdersHistoryPage>> getHistoryOrders(int page) =>
      _guard(() async {
        final res = await _remoteDataSource.fetchOrdersPage(
          'history',
          page: page,
          limit: kOrdersHistoryPageSize,
        );
        return OrdersHistoryPage(items: res.items, total: res.total);
      });

  @override
  Future<Either<OrdersFailure, CustomerOrder>> getOrderDetail(String id) =>
      _guard(() => _remoteDataSource.fetchOrderDetail(id));

  @override
  Future<Either<OrdersFailure, CustomerOrder>> cancelOrder(
    String id,
    String reason,
  ) => _guard(
    () => _remoteDataSource.cancelOrder(id, reason),
    mapFailure: (e) {
      if (e is NoConnectionException) return const OrdersOfflineFailure();
      // 409 claveado al código del backend (§017/§028); el fallback por
      // statusCode cubre respuestas sin el campo (el único 409 que
      // cancel puede emitir hoy es ORDER_NOT_CANCELLABLE).
      if (e is ServerException &&
          (e.errorCode == 'ORDER_NOT_CANCELLABLE' ||
              (e.errorCode == null && e.statusCode == 409))) {
        return OrdersCancelRejectedFailure(e.message);
      }
      return OrdersServerFailure(e.message);
    },
  );

  /// Red de seguridad idéntica a la del checkout: un 200 malformado
  /// (cast del datasource) no es NetworkException — sin el catch de
  /// respaldo la UI quedaría en loading para siempre.
  Future<Either<OrdersFailure, T>> _guard<T>(
    Future<T> Function() call, {
    OrdersFailure Function(NetworkException)? mapFailure,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(OrdersOfflineFailure());
    }
    try {
      return Right(await call());
    } on NetworkException catch (e) {
      return Left((mapFailure ?? _mapFailure)(e));
    } catch (e) {
      return Left(OrdersServerFailure(e.toString()));
    }
  }

  OrdersFailure _mapFailure(NetworkException e) => e is NoConnectionException
      ? const OrdersOfflineFailure()
      : OrdersServerFailure(e.message);
}
