import 'package:equatable/equatable.dart';

import '../../domain/entities/cart_item.dart';

/// Estado del carrito (§020): solo ítems — sin status/failures
/// porque hoy es 100% local (no hay carga remota que pueda fallar).
class CartState extends Equatable {
  const CartState({this.items = const <CartItem>[]});

  final List<CartItem> items;

  /// Unidades totales — el badge del header (Σ quantity).
  int get itemCount => items.fold(0, (s, i) => s + i.quantity);

  /// Subtotal del pedido en construcción.
  int get subtotal => items.fold(0, (s, i) => s + i.lineTotal);

  bool get isEmpty => items.isEmpty;

  @override
  List<Object?> get props => [items];
}
