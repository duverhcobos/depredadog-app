import 'package:dartz/dartz.dart';

import '../failures/orders_failure.dart';
import '../repositories/i_orders_repository.dart';

/// SOLID (SRP): una acción — la página siguiente del historial
/// ("Cargar más" — GET /orders?bucket=history&page=N).
class LoadMoreHistoryUseCase {
  const LoadMoreHistoryUseCase(this._repo);

  final IOrdersRepository _repo;

  Future<Either<OrdersFailure, OrdersHistoryPage>> call(int page) =>
      _repo.getHistoryOrders(page);
}
