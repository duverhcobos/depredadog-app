import 'package:dartz/dartz.dart';

import '../../../../core/network/exceptions/network_exception.dart';
import '../../../../core/network/interfaces/i_network_info.dart';
import '../../domain/entities/admin_day_close.dart';
import '../../domain/entities/admin_new_order_draft.dart';
import '../../domain/entities/admin_order.dart';
import '../../domain/entities/admin_table.dart';
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

  @override
  Future<Either<AdminFailure, AdminOrder>> confirmOrderPayment(
    String orderId,
  ) => _guard(() => _remoteDataSource.confirmPayment(orderId));

  @override
  Future<Either<AdminFailure, AdminDayClose>> getDayClosePreview() =>
      _guard(() => _remoteDataSource.fetchDayClose());

  @override
  Future<Either<AdminFailure, AdminDayClose>> closeDay() =>
      _guard(() => _remoteDataSource.postDayClose());

  @override
  Future<Either<AdminFailure, List<AdminTable>>> getTables() =>
      _guard(() => _remoteDataSource.fetchTables());

  /// El payload del POST se arma acá — data conoce CartItem/
  /// CartModifier: cada fila serializa 1:1 a items[].modifiers del
  /// contrato (optionId + action + replacesOptionId?). tableId solo
  /// viaja en dine_in (prohibido en pickup); payerPhone solo en
  /// transfer (prohibido en cash) — ambas reglas las resuelve el
  /// draft del cubit, el repo solo las respeta.
  @override
  Future<Either<AdminFailure, AdminOrder>> createInPersonOrder(
    AdminNewOrderDraft draft,
  ) => _guard(
    () => _remoteDataSource.createOrder({
      'serviceType': draft.serviceType == AdminServiceType.dineIn
          ? 'dine_in'
          : 'pickup',
      if (draft.tableId != null) 'tableId': draft.tableId,
      'items': [
        for (final i in draft.items)
          {
            'productId': i.productId,
            'quantity': i.quantity,
            'modifiers': [
              for (final m in i.modifiers)
                {
                  'optionId': m.optionId,
                  'action': m.action.name,
                  if (m.replacesOptionId != null)
                    'replacesOptionId': m.replacesOptionId,
                },
            ],
          },
      ],
      'paymentMethod': draft.paymentMethod == AdminPaymentMethod.cash
          ? 'cash'
          : 'transfer',
      if (draft.payerPhone != null) 'payerPhone': draft.payerPhone,
      if (draft.notes != null && draft.notes!.trim().isNotEmpty)
        'notes': draft.notes!.trim(),
    }),
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
    // errorCode viaja también en los no-409 (§042 — TABLE_NOT_FOUND
    // 404, PAYMENT_DISPATCH_FAILED 502, INVALID_ORDER_DATA 400): la
    // comanda elige su toast por código.
    if (e is ServerException) {
      return AdminServerFailure(e.message, errorCode: e.errorCode);
    }
    return AdminServerFailure(e.message);
  }
}
