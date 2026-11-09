import 'package:dartz/dartz.dart';

import '../entities/checkout_store.dart';
import '../entities/saved_address.dart';
import '../failures/checkout_failure.dart';

/// SOLID (DIP): contrato de los datos del checkout — la presentación
/// no conoce HTTP.
abstract class ICheckoutRepository {
  /// GET /addresses — las mías; el backend ordena default-primero
  /// (§014), así que `first` es el prefill honesto del domicilio.
  Future<Either<CheckoutFailure, List<SavedAddress>>> getSavedAddresses();

  /// GET /store/config — nombre, dirección del local, fee de domicilio,
  /// isOpen (backend 013).
  Future<Either<CheckoutFailure, CheckoutStore>> getStoreConfig();

  /// POST /addresses — "Guardar esta ubicación" del form de domicilio.
  /// La app traduce el tipo a label (home→'Casa', work→'Trabajo',
  /// other→texto libre); el backend exige label siempre (§014).
  Future<Either<CheckoutFailure, SavedAddress>> saveAddress({
    required String label,
    required String landmark,
    String? neighborhood,
    required SavedAddressType type,
  });
}
