import 'package:dartz/dartz.dart';

import '../entities/customer_order.dart';
import '../failures/orders_failure.dart';
import '../repositories/i_orders_repository.dart';

/// SOLID (SRP): cancelar el pedido propio (POST /orders/:id/cancel,
/// solo pending — §015). La razón fija del cliente la pone el cubit
/// (el diálogo aprobado no tiene campo de texto — §023).
class CancelOrderUseCase {
  const CancelOrderUseCase(this._repo);

  final IOrdersRepository _repo;

  Future<Either<OrdersFailure, CustomerOrder>> call(String id, String reason) =>
      _repo.cancelOrder(id, reason);
}
