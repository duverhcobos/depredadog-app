import 'package:dartz/dartz.dart';

import '../entities/checkout_store.dart';
import '../entities/saved_address.dart';
import '../failures/checkout_failure.dart';
import '../repositories/i_checkout_repository.dart';

/// Resultado de la carga inicial del checkout — cada pierna lleva su
/// propio Either para que la pantalla degrade por bloque (direcciones
/// vs. datos del local), no en conjunto.
class CheckoutDataResult {
  const CheckoutDataResult({required this.addresses, required this.store});

  final Either<CheckoutFailure, List<SavedAddress>> addresses;
  final Either<CheckoutFailure, CheckoutStore> store;
}

/// SOLID (SRP): una acción — traer en paralelo las direcciones y la
/// config del local que necesita la pantalla. Los dos GET son
/// independientes: un fallo de uno no tumba al otro.
class LoadCheckoutDataUseCase {
  const LoadCheckoutDataUseCase(this._repo);

  final ICheckoutRepository _repo;

  Future<CheckoutDataResult> call() async {
    final results = await Future.wait([
      _repo.getSavedAddresses(),
      _repo.getStoreConfig(),
    ]);
    return CheckoutDataResult(
      addresses: results[0] as Either<CheckoutFailure, List<SavedAddress>>,
      store: results[1] as Either<CheckoutFailure, CheckoutStore>,
    );
  }
}
