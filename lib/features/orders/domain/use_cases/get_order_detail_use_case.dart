import 'package:dartz/dartz.dart';

import '../entities/customer_order.dart';
import '../failures/orders_failure.dart';
import '../repositories/i_orders_repository.dart';

/// SOLID (SRP): refrescar UN pedido al abrir su detalle — el listado
/// omite modifiers a propósito (§015): solo :id los trae, junto al
/// estado más fresco (el stepper cambia server-side).
class GetOrderDetailUseCase {
  const GetOrderDetailUseCase(this._repo);

  final IOrdersRepository _repo;

  Future<Either<OrdersFailure, CustomerOrder>> call(String id) =>
      _repo.getOrderDetail(id);
}
