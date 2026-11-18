import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../models/admin_order_model.dart';
import '../interfaces/i_admin_remote_datasource.dart';

/// SOLID (SRP): solo llama GET /admin/orders y parsea — el Bearer lo pone
/// el AuthInterceptor (rol admin lo exige el RolesGuard del backend), los
/// errores los traduce el repository. Espejo de OrdersRemoteDataSourceImpl.
class AdminRemoteDataSourceImpl implements IAdminRemoteDataSource {
  const AdminRemoteDataSourceImpl({required this._networkService});

  final INetworkService _networkService;

  @override
  Future<({List<AdminOrderModel> items, int total})> fetchQueuePage(
    String bucket, {
    int? page,
    int? limit,
  }) async {
    final response = await _networkService.get(
      '/admin/orders',
      queryParameters: {'bucket': bucket, 'page': ?page, 'limit': ?limit},
    );
    final envelope = response as Map<String, dynamic>;
    return (
      items: (envelope['items'] as List<dynamic>)
          .map((o) => AdminOrderModel.fromJson(o as Map<String, dynamic>))
          .toList(),
      total: envelope['total'] as int,
    );
  }

  @override
  Future<AdminOrderModel> fetchAdminOrder(String orderId) async {
    final response = await _networkService.get('/admin/orders/$orderId');
    return AdminOrderModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<AdminOrderModel> patchOrderStatus(
    String orderId, {
    required String to,
    String? cancelReason,
  }) async {
    final response = await _networkService.patch(
      '/admin/orders/$orderId/status',
      body: {'to': to, 'cancelReason': ?cancelReason},
    );
    return AdminOrderModel.fromJson(response as Map<String, dynamic>);
  }
}
