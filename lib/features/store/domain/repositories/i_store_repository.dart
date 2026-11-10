import 'package:dartz/dartz.dart';

import '../entities/store_open_state.dart';
import '../failures/store_failure.dart';

/// Estado operativo del local (§029) — lo consumen el chip del
/// header, el carrito y futuras pantallas; el checkout mantiene su
/// fetch propio porque necesita el config completo (fee/dirección).
abstract interface class IStoreRepository {
  /// GET /store/config → abierto/cerrado ahora. Either solo para
  /// propagar el fallo de red; el cubit lo convierte en `unknown`.
  Future<Either<StoreFailure, StoreOpenState>> getOpenState();
}
