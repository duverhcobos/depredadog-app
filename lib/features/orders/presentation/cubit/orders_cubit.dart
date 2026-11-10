import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/customer_order.dart';
import '../../domain/failures/orders_failure.dart';
import '../../domain/repositories/i_orders_repository.dart';
import '../../domain/use_cases/cancel_order_use_case.dart';
import '../../domain/use_cases/get_order_detail_use_case.dart';
import '../../domain/use_cases/load_more_history_use_case.dart';
import '../../domain/use_cases/load_orders_use_case.dart';
import 'orders_state.dart';

/// SOLID (SRP): único dueño del estado del tab Pedidos (§027 — real,
/// GET/POST /orders del backend 015): listas activo/historial,
/// paginación del historial, refresh de un pedido y la acción de
/// cancelar. SINGLETON como CartCubit: el tab y su detalle
/// /orders/:id comparten la misma instancia (revisor-ui §023).
class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit({
    required LoadOrdersUseCase loadOrdersUseCase,
    required LoadMoreHistoryUseCase loadMoreHistoryUseCase,
    required GetOrderDetailUseCase getOrderDetailUseCase,
    required CancelOrderUseCase cancelOrderUseCase,
  }) : _loadOrders = loadOrdersUseCase,
       _loadMoreHistory = loadMoreHistoryUseCase,
       _getOrderDetail = getOrderDetailUseCase,
       _cancelOrder = cancelOrderUseCase,
       super(const OrdersState());

  final LoadOrdersUseCase _loadOrders;
  final LoadMoreHistoryUseCase _loadMoreHistory;
  final GetOrderDetailUseCase _getOrderDetail;
  final CancelOrderUseCase _cancelOrder;

  /// Guardia de reentry de loadOrders — es carga completa (inicial,
  /// pull-to-refresh, reload al entrar al tab y resync tras un
  /// cancel rechazado); un loading paralelo no compite.
  bool _loading = false;

  /// Época de la carga completa — loadMoreHistory captura la suya
  /// antes del await y descarta su página si un loadOrders corrió en
  /// el medio (sin ella, una page-N vieja se anexaba a la page-1
  /// fresca: salto + duplicados — revisor §027).
  int _loadEpoch = 0;

  /// Razón fija de la cancelación del cliente — el diálogo aprobado
  /// no tiene campo de texto (§023); viaja como `reason` del body.
  static const _cancelReason = 'Cancelado por el cliente';

  /// Carga inicial / pull-to-refresh / reload al entrar al tab:
  /// activos + primera página del historial en paralelo — cada pierna
  /// degrada por separado (una falla no tumba la otra). El spinner de
  /// pantalla completa solo existe sin datos previos — en refresh el
  /// contenido queda (el pull no desmonta el árbol — revisor §027).
  Future<void> loadOrders() async {
    if (_loading) return;
    _loading = true;
    _loadEpoch++;
    try {
      emit(
        state.copyWith(
          dataLoading: state.isEmpty,
          activeFailed: false,
          historyFailed: false,
          historyLoadingMore: false,
          historyLoadMoreFailed: false,
        ),
      );
      final result = await _loadOrders();
      if (isClosed) return;
      result.active.fold(
        (failure) => emit(state.copyWith(active: const [], activeFailed: true)),
        (orders) => emit(state.copyWith(active: orders, activeFailed: false)),
      );
      result.history.fold(
        (failure) => emit(
          state.copyWith(
            history: const [],
            historyTotal: 0,
            historyFailed: true,
          ),
        ),
        (page) => emit(
          state.copyWith(
            history: page.items,
            historyTotal: page.total,
            historyFailed: false,
          ),
        ),
      );
      emit(state.copyWith(dataLoading: false));
    } finally {
      _loading = false;
    }
  }

  /// "Cargar más" del historial — la página se deriva de lo ya
  /// cargado (el retry tras falla repite la misma página). No corre
  /// con un loadOrders en vuelo y descarta su resultado si uno corrió
  /// en el medio (época); el anexar deduplica por id — un pedido que
  /// migra a terminal corre el borde de página server-side (revisor
  /// §027).
  Future<void> loadMoreHistory() async {
    if (state.historyLoadingMore || _loading) return;
    emit(
      state.copyWith(historyLoadingMore: true, historyLoadMoreFailed: false),
    );
    final epoch = _loadEpoch;
    final page = state.history.length ~/ kOrdersHistoryPageSize + 1;
    final result = await _loadMoreHistory(page);
    if (isClosed || epoch != _loadEpoch) return;
    result.fold(
      (failure) => emit(
        state.copyWith(historyLoadingMore: false, historyLoadMoreFailed: true),
      ),
      (page) => emit(
        state.copyWith(
          history: [
            ...state.history,
            ...page.items.where(
              (n) => state.history.every((e) => e.id != n.id),
            ),
          ],
          historyTotal: page.total,
          historyLoadingMore: false,
        ),
      ),
    );
  }

  /// Refresh de UN pedido al abrir su detalle — GET /orders/:id trae
  /// el estado fresco + los modifiers que el listado omite (§015).
  /// Falla silenciosa: el detalle queda con el snapshot del listado
  /// (la resincronización la da el pull-to-refresh del tab).
  Future<void> refreshOrder(String id) async {
    final result = await _getOrderDetail(id);
    if (isClosed) return;
    result.fold((_) {}, _upsert);
  }

  /// Cancela un pedido "Recibido" (POST /orders/:id/cancel — solo
  /// pending, §015). Devuelve `null` en éxito o LA FAILURE — la UI
  /// elige su texto l10n; el `message` del 409 del servidor viene en
  /// inglés y nunca se muestra crudo (corrección del revisor §027).
  /// Cualquier falla dispara un loadOrders silencioso de
  /// resincronización (el 409 dice que el pedido ya cambió server-side).
  Future<OrdersFailure?> cancelOrder(String id) async {
    final result = await _cancelOrder(id, _cancelReason);
    if (isClosed) return null;
    return result.fold(
      (failure) {
        unawaited(loadOrders());
        return failure;
      },
      (order) {
        _upsert(order);
        return null;
      },
    );
  }

  /// Inserta/reemplaza la entidad donde corresponda: un terminal va
  /// al frente del historial y sale de activos (la cancelada por el
  /// admin cambió de bucket); uno vivo reemplaza su posición en
  /// activos o en el historial, y si no estaba entra al frente de
  /// activos (detalle abierto sin snapshot del listado). El migrado a
  /// terminal es una fila NUEVA del bucket → historyTotal+1 si no
  /// estaba ya cargado (revisor §027).
  void _upsert(CustomerOrder order) {
    if (order.isTerminal) {
      final alreadyInHistory = state.history.any((o) => o.id == order.id);
      emit(
        state.copyWith(
          active: state.active.where((o) => o.id != order.id).toList(),
          history: [order, ...state.history.where((o) => o.id != order.id)],
          historyTotal: alreadyInHistory
              ? state.historyTotal
              : state.historyTotal + 1,
        ),
      );
      return;
    }
    final activeIndex = state.active.indexWhere((o) => o.id == order.id);
    if (activeIndex >= 0) {
      emit(state.copyWith(active: [...state.active]..[activeIndex] = order));
      return;
    }
    final historyIndex = state.history.indexWhere((o) => o.id == order.id);
    if (historyIndex >= 0) {
      emit(state.copyWith(history: [...state.history]..[historyIndex] = order));
      return;
    }
    emit(state.copyWith(active: [order, ...state.active]));
  }
}
