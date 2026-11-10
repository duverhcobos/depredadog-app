import '../../../domain/entities/store_open_state.dart';

/// Fuente remota del estado del local — GET /store/config.
abstract interface class IStoreRemoteDataSource {
  /// Lanza NetworkException; el repositorio la traduce.
  Future<StoreOpenState> fetchOpenState();
}
