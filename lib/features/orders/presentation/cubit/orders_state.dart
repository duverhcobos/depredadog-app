import 'package:equatable/equatable.dart';

import '../../domain/entities/customer_order.dart';

/// Estado del tab Pedidos (§027): lista "En curso" (no terminales —
/// done/cancelled pasan al historial) + historial más reciente
/// primero, con flags de carga/error por sección (cada pierna del
/// fan-out degrada por separado) y la paginación del historial
/// ("Cargar más" — GET /orders?bucket=history&page=N).
class OrdersState extends Equatable {
  const OrdersState({
    this.active = const [],
    this.history = const [],
    this.dataLoading = true,
    this.activeFailed = false,
    this.historyFailed = false,
    this.historyTotal = 0,
    this.historyLoadingMore = false,
    this.historyLoadMoreFailed = false,
  });

  /// Pedidos vivos (received/confirmed/preparing — el cliente sigue
  /// su progreso).
  final List<CustomerOrder> active;

  /// Pedidos terminados (done/cancelled), más reciente primero.
  final List<CustomerOrder> history;

  /// Carga inicial / refresh completo en vuelo — el tab arranca en
  /// true (los datos reales llegan con el primer loadOrders).
  final bool dataLoading;

  /// La pierna activa del GET /orders falló — fila inline de
  /// error+retry donde irían las cards (familia §025).
  final bool activeFailed;

  /// La pierna del historial falló — fila inline bajo el heading.
  final bool historyFailed;

  /// Total del bucket history que reporta el envelope — `history`
  /// puede tener menos (paginación).
  final int historyTotal;

  /// "Cargar más" en vuelo — la fila final muestra mini-spinner.
  final bool historyLoadingMore;

  /// El "Cargar más" falló — la misma fila muestra error+retry.
  final bool historyLoadMoreFailed;

  bool get isEmpty => active.isEmpty && history.isEmpty;

  /// Queda historial por traer según el total del bucket.
  bool get historyHasMore => history.length < historyTotal;

  OrdersState copyWith({
    List<CustomerOrder>? active,
    List<CustomerOrder>? history,
    bool? dataLoading,
    bool? activeFailed,
    bool? historyFailed,
    int? historyTotal,
    bool? historyLoadingMore,
    bool? historyLoadMoreFailed,
  }) => OrdersState(
    active: active ?? this.active,
    history: history ?? this.history,
    dataLoading: dataLoading ?? this.dataLoading,
    activeFailed: activeFailed ?? this.activeFailed,
    historyFailed: historyFailed ?? this.historyFailed,
    historyTotal: historyTotal ?? this.historyTotal,
    historyLoadingMore: historyLoadingMore ?? this.historyLoadingMore,
    historyLoadMoreFailed: historyLoadMoreFailed ?? this.historyLoadMoreFailed,
  );

  @override
  List<Object?> get props => [
    active,
    history,
    dataLoading,
    activeFailed,
    historyFailed,
    historyTotal,
    historyLoadingMore,
    historyLoadMoreFailed,
  ];
}
