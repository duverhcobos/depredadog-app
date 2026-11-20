import 'package:dartz/dartz.dart';

import '../entities/admin_new_order_draft.dart';
import '../entities/admin_order.dart';
import '../failures/admin_failure.dart';
import '../repositories/i_admin_repository.dart';

/// SOLID (SRP): una acción — crear el pedido presencial del
/// borrador (POST /admin/orders — §042). dineIn nace confirmed,
/// pickup nace pending (backend §019).
class CreateAdminOrderUseCase {
  const CreateAdminOrderUseCase(this._repository);

  final IAdminRepository _repository;

  Future<Either<AdminFailure, AdminOrder>> call(
    AdminNewOrderDraft draft,
  ) => _repository.createInPersonOrder(draft);
}
