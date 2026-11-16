import '../../models/admin_order_model.dart';

/// Puerto remoto de la cola del local (GET /admin/orders — backend §019).
/// El envelope {items,total,page,limit}: `active` no pagina (page/limit se
/// ignoran ahí); `history` sí (la pantalla provisional consume página 1).
abstract class IAdminRemoteDataSource {
  Future<({List<AdminOrderModel> items, int total})> fetchQueuePage(
    String bucket, {
    int? page,
    int? limit,
  });

  /// Comanda completa por id (§039 — GET /admin/orders/:id): el
  /// listado omite modifiers a propósito; el detalle los trae junto
  /// al estado más fresco.
  Future<AdminOrderModel> fetchAdminOrder(String orderId);
}
