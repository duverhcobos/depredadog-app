import 'package:dartz/dartz.dart';

import '../entities/saved_address.dart';
import '../failures/checkout_failure.dart';
import '../repositories/i_checkout_repository.dart';

/// SOLID (SRP): una acción — persistir la ubicación nueva cuando el
/// cliente marca "Guardar esta ubicación" (POST /addresses, §014).
class SaveAddressUseCase {
  const SaveAddressUseCase(this._repo);

  final ICheckoutRepository _repo;

  Future<Either<CheckoutFailure, SavedAddress>> call({
    required String label,
    required String landmark,
    String? neighborhood,
    required SavedAddressType type,
  }) => _repo.saveAddress(
    label: label,
    landmark: landmark,
    neighborhood: neighborhood,
    type: type,
  );
}
