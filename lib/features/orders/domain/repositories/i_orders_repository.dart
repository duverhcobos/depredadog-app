import 'package:dartz/dartz.dart';

import '../entities/customer_order.dart';
import '../failures/orders_failure.dart';

/// Tamaño de página del historial — el repo lo envía como `limit`
/// explícito y el cubit deriva la página siguiente de él (una sola
/// fuente; sin él la app duplicaba el default del servidor — revisor
/// §027).
const kOrdersHistoryPageSize = 20;

/// SOLID (DIP): contrato de Pedidos — la presentación no conoce HTTP.
abstract class IOrdersRepository {
  /// GET /orders?bucket=active — en curso, sin paginar.
  Future<Either<OrdersFailure, List<CustomerOrder>>> getActiveOrders();

  /// GET /orders?bucket=history&page=N — terminados paginados;
  /// devuelve items + total del bucket para el "Cargar más".
  Future<Either<OrdersFailure, OrdersHistoryPage>> getHistoryOrders(int page);

  /// GET /orders/:id — detalle completo CON modifiers (única fuente
  /// del panel por secciones — el listado los omite, §015).
  Future<Either<OrdersFailure, CustomerOrder>> getOrderDetail(String id);

  /// POST /orders/:id/cancel — solo pending; 409 llega como
  /// OrdersCancelRejectedFailure (el mensaje queda para logging — la
  /// UI muestra su propio texto l10n, el del servidor viene en inglés).
  Future<Either<OrdersFailure, CustomerOrder>> cancelOrder(
    String id,
    String reason,
  );
}

/// Página del historial — la entidad lista vive en domain/entities
/// pero el conteo del bucket es dato de paginación propio del repo.
class OrdersHistoryPage {
  const OrdersHistoryPage({required this.items, required this.total});

  final List<CustomerOrder> items;
  final int total;
}
