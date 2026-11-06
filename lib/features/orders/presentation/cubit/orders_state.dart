import 'package:equatable/equatable.dart';

import '../../domain/entities/customer_order.dart';

/// Estado del tab Pedidos (§023, solo presentación): lista "En curso"
/// (no terminales — done/cancelled pasan al historial) + historial
/// más reciente primero.
class OrdersState extends Equatable {
  const OrdersState({this.active = const [], this.history = const []});

  /// Pedidos vivos (received/confirmed/preparing — el cliente sigue
  /// su progreso).
  final List<CustomerOrder> active;

  /// Pedidos terminados (done/cancelled), más reciente primero.
  final List<CustomerOrder> history;

  bool get isEmpty => active.isEmpty && history.isEmpty;

  OrdersState copyWith({
    List<CustomerOrder>? active,
    List<CustomerOrder>? history,
  }) => OrdersState(
    active: active ?? this.active,
    history: history ?? this.history,
  );

  @override
  List<Object?> get props => [active, history];
}
