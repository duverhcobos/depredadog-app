import 'package:dartz/dartz.dart';

import '../entities/admin_order.dart';
import '../failures/admin_failure.dart';

/// Tamaño de página del historial admin (convención orders §027).
const kAdminHistoryPageSize = 20;

/// Una página del bucket history — items + total del servidor.
class AdminHistoryPage {
  const AdminHistoryPage({required this.items, required this.total});

  final List<AdminOrder> items;
  final int total;
}

/// Puerto del repositorio de Cocina (GET /admin/orders por bucket).
abstract class IAdminRepository {
  /// Bucket `active`: en curso + done sin cerrar (no pagina).
  Future<Either<AdminFailure, List<AdminOrder>>> getActiveOrders();

  /// Bucket `history`: cancelados + done cerrados, paginado.
  Future<Either<AdminFailure, AdminHistoryPage>> getHistoryOrders(int page);

  /// Comanda completa por id (§039 — GET /admin/orders/:id): el
  /// detalle la pide al abrir — modifiers + estado fresco que el
  /// listado omite.
  Future<Either<AdminFailure, AdminOrder>> getOrderDetail(String orderId);

  /// PATCH /admin/orders/:id/status (§040): `to` es el estado destino
  /// en inglés del backend (confirmed|preparing|ready|done|cancelled);
  /// `cancelReason` solo con `cancelled`. Devuelve la entidad completa
  /// con `statusChangedAt` re-sellado.
  Future<Either<AdminFailure, AdminOrder>> updateOrderStatus(
    String orderId, {
    required String to,
    String? cancelReason,
  });
}
