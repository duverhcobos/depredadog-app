import 'package:dartz/dartz.dart';

import '../../../../core/network/exceptions/network_exception.dart';
import '../../../../core/network/interfaces/i_network_info.dart';
import '../../domain/entities/admin_order.dart';
import '../../domain/failures/admin_failure.dart';
import '../../domain/repositories/i_admin_repository.dart';
import '../datasources/interfaces/i_admin_remote_datasource.dart';

/// SOLID (SRP): orquesta datasource + conectividad; traduce
/// NetworkException → AdminFailure (la UI nunca ve excepciones crudas) —
/// el mismo `_guard` genérico de OrdersRepositoryImpl.
class AdminRepositoryImpl implements IAdminRepository {
  const AdminRepositoryImpl({
    required this._remoteDataSource,
    required this._networkInfo,
  });

  final IAdminRemoteDataSource _remoteDataSource;
  final INetworkInfo _networkInfo;

  @override
  Future<Either<AdminFailure, List<AdminOrder>>> getActiveOrders() =>
      _guard(() async => (await _remoteDataSource.fetchQueuePage('active')).items);

  @override
  Future<Either<AdminFailure, AdminHistoryPage>> getHistoryOrders(int page) =>
      _guard(() async {
        final res = await _remoteDataSource.fetchQueuePage(
          'history',
          page: page,
          limit: kAdminHistoryPageSize,
        );
        return AdminHistoryPage(items: res.items, total: res.total);
      });

  @override
  Future<Either<AdminFailure, AdminOrder>> getOrderDetail(String orderId) =>
      _guard(() => _remoteDataSource.fetchAdminOrder(orderId));

  @override
  Future<Either<AdminFailure, AdminOrder>> updateOrderStatus(
    String orderId, {
    required String to,
    String? cancelReason,
  }) => _guard(
    () => _remoteDataSource.patchOrderStatus(
      orderId,
      to: to,
      cancelReason: cancelReason,
    ),
  );

  /// Red de seguridad idéntica a la de orders: un 200 malformado (cast del
  /// datasource) no es NetworkException — sin el catch de respaldo la UI
  /// quedaría en loading para siempre.
  Future<Either<AdminFailure, T>> _guard<T>(Future<T> Function() call) async {
    if (!await _networkInfo.isConnected) {
      return const Left(AdminOfflineFailure());
    }
    try {
      return Right(await call());
    } on NetworkException catch (e) {
      return Left(_mapFailure(e));
    } catch (e) {
      return Left(AdminServerFailure(e.toString()));
    }
  }

  AdminFailure _mapFailure(NetworkException e) {
    if (e is NoConnectionException) return const AdminOfflineFailure();
    if (e is ServerException && e.statusCode == 409) {
      return AdminConflictFailure(e.errorCode ?? 'CONFLICT');
    }
    return AdminServerFailure(e.message);
  }
}
