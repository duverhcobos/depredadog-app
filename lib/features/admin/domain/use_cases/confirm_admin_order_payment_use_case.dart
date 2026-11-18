import 'package:dartz/dartz.dart';

import '../entities/admin_order.dart';
import '../failures/admin_failure.dart';
import '../repositories/i_admin_repository.dart';

/// "Registrar pago" real (§041): POST confirm-payment — cobra y
/// avanza la orden en el mismo hecho del backend.
class ConfirmAdminOrderPaymentUseCase {
  const ConfirmAdminOrderPaymentUseCase(this._repository);

  final IAdminRepository _repository;

  Future<Either<AdminFailure, AdminOrder>> call(String orderId) =>
      _repository.confirmOrderPayment(orderId);
}
