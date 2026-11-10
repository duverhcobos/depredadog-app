import 'package:dartz/dartz.dart';

import '../entities/store_open_state.dart';
import '../failures/store_failure.dart';
import '../repositories/i_store_repository.dart';

/// SOLID (SRP): una sola acción de negocio — consultar si el local
/// está abierto ahora (GET /store/config → isOpen). Pass-through
/// deliberado: la regla de la casa pide un UC por acción aunque el
/// cuerpo sea delegación pura (uniformidad con el resto de cubits).
class GetStoreOpenStateUseCase {
  const GetStoreOpenStateUseCase(this._repo);

  final IStoreRepository _repo;

  Future<Either<StoreFailure, StoreOpenState>> call() =>
      _repo.getOpenState();
}
