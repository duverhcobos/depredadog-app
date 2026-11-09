import 'package:dartz/dartz.dart';

import '../entities/placed_order.dart';
import '../failures/checkout_failure.dart';
import '../repositories/i_checkout_repository.dart';
import 'create_order_params.dart';

/// SOLID (SRP): una acción — confirmar el pedido real (POST /orders,
/// §026/backend 015). La validación de negocio es server-side; aquí
/// solo viaja el comando ya armado por el cubit.
class CreateOrderUseCase {
  const CreateOrderUseCase(this._repo);

  final ICheckoutRepository _repo;

  Future<Either<CheckoutFailure, PlacedOrder>> call(
    CreateOrderParams params,
  ) => _repo.createOrder(params);
}
