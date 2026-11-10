import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../../domain/entities/store_open_state.dart';
import '../interfaces/i_store_remote_datasource.dart';

/// GET /store/config → `isOpen` del negocio (backend 013). Solo lee
/// ese campo — el config completo (fee/dirección/horario) lo consume
/// el checkout por su propio datasource.
class StoreRemoteDataSourceImpl implements IStoreRemoteDataSource {
  const StoreRemoteDataSourceImpl({required this.networkService});

  final INetworkService networkService;

  @override
  Future<StoreOpenState> fetchOpenState() async {
    // INetworkService devuelve el body ya decodificado (los errores
    // HTTP llegan como NetworkException — los traduce el repository).
    final data = await networkService.get('/store/config');
    // Parseo defensivo: body no-Map o isOpen ausente → `unknown`
    // (no se finge cerrado ni abierto — el consumidor decide).
    if (data is! Map<String, dynamic>) return StoreOpenState.unknown;
    final isOpen = data['isOpen'];
    return isOpen is bool
        ? (isOpen ? StoreOpenState.open : StoreOpenState.closed)
        : StoreOpenState.unknown;
  }
}
