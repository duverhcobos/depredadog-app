import '../../models/admin_day_close_model.dart';
import '../../models/admin_order_model.dart';
import '../../models/admin_table_model.dart';

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

  /// PATCH /admin/orders/:id/status (§040 — backend §022): mueve el
  /// pedido por la matriz de 5 estados (`to`: confirmed | preparing |
  /// ready | done | cancelled). `cancelReason` solo viaja con
  /// `to='cancelled'`. Devuelve la vista admin completa con
  /// `statusChangedAt` re-sellado — el reloj de la cola lo pone el
  /// servidor. El 409 sale como ServerException con errorCode
  /// (INVALID_STATUS_TRANSITION | PAYMENT_NOT_SETTLED).
  Future<AdminOrderModel> patchOrderStatus(
    String orderId, {
    required String to,
    String? cancelReason,
  });

  /// POST /admin/orders/:id/confirm-payment (§041 — backend §022):
  /// cobra el pago pending (claim atómico, idempotente — un pago ya
  /// `paid` responde la misma orden) y AVANZA la orden cuando el
  /// estado lo amerita: pending+presencial+pickup→confirmed,
  /// ready→done. El 409 sale como ServerException con errorCode
  /// (PAYMENT_NOT_CONFIRMABLE).
  Future<AdminOrderModel> confirmPayment(String orderId);

  /// GET /admin/day-close (§041 — backend §022): preview de solo
  /// lectura — los terminales (`done`+`cancelled`) aún sin cerrar.
  Future<AdminDayCloseModel> fetchDayClose();

  /// POST /admin/day-close (§041 — backend §022): ejecuta el cierre
  /// atómico — crea el registro, estampa `day_close_id` en los
  /// terminales y devuelve el snapshot persistido.
  Future<AdminDayCloseModel> postDayClose();

  /// GET /admin/tables (§042 — backend §019): mesas con ocupación
  /// en vivo para el picker de la comanda.
  Future<List<AdminTableModel>> fetchTables();

  /// POST /admin/orders (§042 — backend §019): crea el presencial.
  /// `payload` ya viene en forma JSON del repo (serviceType, tableId?,
  /// items con modifiers, paymentMethod, payerPhone?, notes?). 201 →
  /// la vista admin completa; 400/404/409/502 salen como
  /// ServerException con errorCode.
  Future<AdminOrderModel> createOrder(Map<String, dynamic> payload);
}
