import '../../models/customer_order_model.dart';

/// Contrato del datasource remoto de Pedidos — endpoints §015;
/// devuelve models/maps crudos, errores como NetworkException.
abstract class IOrdersRemoteDataSource {
  /// GET /orders?bucket — activos sin `page`; historial con `page` +
  /// `limit` explícito (el envelope devuelve items + total para el
  /// "Cargar más").
  Future<({List<CustomerOrderModel> items, int total})> fetchOrdersPage(
    String bucket, {
    int? page,
    int? limit,
  });
  Future<CustomerOrderModel> fetchOrderDetail(String id);
  Future<CustomerOrderModel> cancelOrder(String id, String reason);
}
