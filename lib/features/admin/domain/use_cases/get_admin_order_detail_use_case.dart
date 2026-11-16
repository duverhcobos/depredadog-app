import 'package:dartz/dartz.dart';

import '../entities/admin_order.dart';
import '../failures/admin_failure.dart';
import '../repositories/i_admin_repository.dart';

/// SOLID (SRP): refrescar UNA comanda al abrir su detalle (§039) —
/// el listado omite modifiers a propósito (payload liviano del
/// kanban): solo :id los trae, junto al estado más fresco. Espejo
/// de GetOrderDetailUseCase del cliente (§015).
class GetAdminOrderDetailUseCase {
  const GetAdminOrderDetailUseCase(this._repository);

  final IAdminRepository _repository;

  Future<Either<AdminFailure, AdminOrder>> call(String orderId) =>
      _repository.getOrderDetail(orderId);
}
