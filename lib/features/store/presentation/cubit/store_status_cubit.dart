import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/store_open_state.dart';
import '../../domain/use_cases/get_store_open_state.dart';

/// Estado del local como enum directo (§029) — no necesita clase de
/// estado: el único dato es abierto/cerrado/desconocido.
///
/// Singleton de shell (registrado en DI + BlocProvider.value del
/// router, como CatalogCubit): el chip del header lo muestra siempre;
/// el carrito dispara refresh() al entrar para que el estado esté
/// fresco donde importa (la puerta del pago).
///
/// `refresh()` fallido → `unknown` solo si aún no se conoce nada:
/// un refresh que falla DESPUÉS de un estado conocido conserva el
/// último valor (un parpadeo de red no debe apagar el chip ni
/// bloquear el carrito — la compuerta real es el checkout/backend).
class StoreStatusCubit extends Cubit<StoreOpenState> {
  StoreStatusCubit({required this._getOpenState})
    : super(StoreOpenState.unknown);

  final GetStoreOpenStateUseCase _getOpenState;

  Future<void> refresh() async {
    final result = await _getOpenState();
    if (isClosed) return;
    result.fold((_) {
      if (state == StoreOpenState.unknown) {
        // Re-emit deliberado (la guarda solo evita work innecesario):
        // en bloc 9.x el primer emit del valor inicial SÍ publica —
        // consumer/tests ven el unknown como evento, no como silencio.
        emit(StoreOpenState.unknown);
      }
      // Estado conocido → se conserva (último valor válido).
    }, emit);
  }
}
