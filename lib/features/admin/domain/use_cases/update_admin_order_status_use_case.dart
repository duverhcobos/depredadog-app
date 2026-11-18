import 'package:dartz/dartz.dart';

import '../entities/admin_order.dart';
import '../failures/admin_failure.dart';
import '../repositories/i_admin_repository.dart';

/// SOLID (SRP): PATCH /admin/orders/:id/status — la única puerta del
/// dominio para mover un pedido por la matriz §022 (avance o
/// cancelación). El `to` llega ya resuelto desde el cubit (inglés,
/// contrato backend); el use case no conoce la matriz — solo reenvía
/// y deja el 409 al repository.
class UpdateAdminOrderStatusUseCase {
  const UpdateAdminOrderStatusUseCase(this._repository);

  final IAdminRepository _repository;

  Future<Either<AdminFailure, AdminOrder>> call(
    String orderId, {
    required String to,
    String? cancelReason,
  }) => _repository.updateOrderStatus(
    orderId,
    to: to,
    cancelReason: cancelReason,
  );
}
