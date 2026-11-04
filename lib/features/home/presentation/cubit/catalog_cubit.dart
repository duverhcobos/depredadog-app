import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/logging/interfaces/i_logger_service.dart';
import '../../domain/use_cases/get_catalog_menu_use_case.dart';
import 'catalog_state.dart';

/// SOLID (SRP): fuente única del menú para las 3 pantallas de catálogo.
/// lazySingleton en el shell — la misma instancia sirve home, lista y
/// detalle (no se re-pide por pantalla ni se duplica el caché).
///
/// `load()`: primera carga (o después de un error) — muestra loading
/// solo cuando no hay datos. `refresh()`: re-pide al entrar a cada
/// pantalla — SILENCIOSO: con datos ya visibles no hay flicker, y si
/// falla se queda con el caché (la disponibilidad real se revalida al
/// crear la orden).
class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit({
    required GetCatalogMenuUseCase getCatalogMenuUseCase,
    required this._logger,
  }) : _getMenu = getCatalogMenuUseCase,
       super(const CatalogState.initial());

  final GetCatalogMenuUseCase _getMenu;
  final ILoggerService _logger;

  Future<void>? _inFlight;

  /// Carga inicial. No-op si ya hay datos (salvo forceRefresh).
  Future<void> load({bool forceRefresh = false}) =>
      _run(forceRefresh: forceRefresh);

  /// Re-pide al entrar a una pantalla — siempre fuerza el fetch,
  /// deduplicado con cualquier otra llamada en vuelo.
  Future<void> refresh() => _run(forceRefresh: true);

  Future<void> _run({required bool forceRefresh}) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    if (!forceRefresh && state.status == CatalogStatus.success) {
      return Future.value();
    }
    final future = _fetch();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<void> _fetch() async {
    if (state.categories.isEmpty) {
      emit(const CatalogState(status: CatalogStatus.loading, categories: []));
    }
    final result = await _getMenu();
    result.fold(
      (failure) {
        if (state.categories.isNotEmpty) {
          // Refresh falló con datos viejos → se queda con ellos (solo
          // log; nada de toast ni error view — UX acordada).
          _logger.warning(
            'Catalog refresh failed, keeping cached menu',
            tag: 'CatalogCubit',
          );
          return;
        }
        emit(
          CatalogState(
            status: CatalogStatus.error,
            categories: const [],
            failure: failure,
          ),
        );
      },
      (menu) =>
          emit(CatalogState(status: CatalogStatus.success, categories: menu)),
    );
  }
}
