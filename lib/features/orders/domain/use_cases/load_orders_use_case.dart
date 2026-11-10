import 'package:dartz/dartz.dart';

import '../entities/customer_order.dart';
import '../failures/orders_failure.dart';
import '../repositories/i_orders_repository.dart';

/// Resultado de la carga del tab — cada pierna degrada por separado
/// (activos puede llegar aunque el historial falle, y viceversa).
class OrdersDataResult {
  const OrdersDataResult({required this.active, required this.history});

  final Either<OrdersFailure, List<CustomerOrder>> active;
  final Either<OrdersFailure, OrdersHistoryPage> history;
}

/// SOLID (SRP): carga inicial / pull-to-refresh / reload al entrar
/// al tab — activos + primera página del historial en paralelo.
class LoadOrdersUseCase {
  const LoadOrdersUseCase(this._repo);

  final IOrdersRepository _repo;

  Future<OrdersDataResult> call() async {
    final results = await Future.wait([
      _repo.getActiveOrders(),
      _repo.getHistoryOrders(1),
    ]);
    return OrdersDataResult(
      active: results[0] as Either<OrdersFailure, List<CustomerOrder>>,
      history: results[1] as Either<OrdersFailure, OrdersHistoryPage>,
    );
  }
}
