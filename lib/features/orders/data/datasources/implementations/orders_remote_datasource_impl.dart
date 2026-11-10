import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../models/customer_order_model.dart';
import '../interfaces/i_orders_remote_datasource.dart';

/// SOLID (SRP): solo llama los endpoints y parsea — el Bearer lo pone
/// el AuthInterceptor, los errores los traduce el repository.
class OrdersRemoteDataSourceImpl implements IOrdersRemoteDataSource {
  const OrdersRemoteDataSourceImpl({required this._networkService});

  final INetworkService _networkService;

  /// El envelope {items,total,page,limit} — items + total para el
  /// "Cargar más"; `page`/`limit` null (bucket active) no paginan.
  @override
  Future<({List<CustomerOrderModel> items, int total})> fetchOrdersPage(
    String bucket, {
    int? page,
    int? limit,
  }) async {
    final response = await _networkService.get(
      '/orders',
      queryParameters: {'bucket': bucket, 'page': ?page, 'limit': ?limit},
    );
    final envelope = response as Map<String, dynamic>;
    return (
      items: (envelope['items'] as List<dynamic>)
          .map((o) => CustomerOrderModel.fromJson(o as Map<String, dynamic>))
          .toList(),
      total: envelope['total'] as int,
    );
  }

  @override
  Future<CustomerOrderModel> fetchOrderDetail(String id) async {
    final response = await _networkService.get('/orders/$id');
    return CustomerOrderModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<CustomerOrderModel> cancelOrder(String id, String reason) async {
    final response = await _networkService.post(
      '/orders/$id/cancel',
      body: {'reason': reason},
    );
    return CustomerOrderModel.fromJson(response as Map<String, dynamic>);
  }
}
