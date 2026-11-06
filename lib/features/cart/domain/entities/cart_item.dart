import 'package:equatable/equatable.dart';

import 'cart_modifier.dart';

/// Ítem del carrito = producto + personalización completa + cantidad
/// (§020). Todo snapshot: el carrito no consulta la carta — si el
/// producto cambia de precio o desaparece, la orden se revalida en
/// el backend al crearla.
class CartItem extends Equatable {
  const CartItem({
    required this.id,
    required this.productId,
    required this.productSlug,
    required this.productName,
    required this.unitBase,
    required this.modifiers,
    this.includedNames = const [],
    this.imageUrl,
    this.quantity = 1,
  });

  /// Id local `cart-<n>` — key de lista y futuras ediciones.
  final String id;

  final String productId;
  final String productSlug;
  final String productName;

  /// Foto remota (null hoy — el tile usa el asset por slug).
  final String? imageUrl;

  /// basePrice snapshot.
  final int unitBase;

  /// Personalización como filas added/removed — mapea 1:1 a
  /// order_item_modifiers. Orden de composición: quitados,
  /// reemplazos (removed + added), adicionales, toppings, salsas.
  final List<CartModifier> modifiers;

  /// Ingredientes que el ítem LLEVA (includedByDefault − quitados −
  /// reemplazados) — snapshot para el desplegable "Lleva:" del tile
  /// (§021). Se captura al agregar/guardar con el producto a la mano.
  final List<String> includedNames;

  final int quantity;

  /// Precio unitario con adicionales — la fila muestra ESTE
  /// (lo que paga cada unidad), no el base.
  int get unitPrice =>
      unitBase +
      modifiers
          .where((m) => m.action == CartModifierAction.added)
          .fold(0, (s, m) => s + m.priceDelta);

  int get lineTotal => unitPrice * quantity;

  /// Mismo producto + MISMO conjunto de modificadores → al
  /// re-agregar suma cantidad, no duplica fila. La comparación es
  /// por clave `optionId:action:priceDelta` (orden irrelevante —
  /// los sets del detalle no garantizan orden de selección).
  bool sameConfiguration(CartItem other) {
    if (other.productId != productId ||
        other.modifiers.length != modifiers.length) {
      return false;
    }
    String key(CartModifier m) =>
        '${m.optionId}:${m.action.name}:${m.priceDelta}';
    final a = {for (final m in modifiers) key(m)};
    final b = {for (final m in other.modifiers) key(m)};
    return a.length == b.length && a.containsAll(b);
  }

  CartItem copyWith({
    String? id,
    List<CartModifier>? modifiers,
    List<String>? includedNames,
    int? quantity,
  }) => CartItem(
    id: id ?? this.id,
    productId: productId,
    productSlug: productSlug,
    productName: productName,
    imageUrl: imageUrl,
    unitBase: unitBase,
    modifiers: modifiers ?? this.modifiers,
    includedNames: includedNames ?? this.includedNames,
    quantity: quantity ?? this.quantity,
  );

  @override
  List<Object?> get props => [
    id,
    productId,
    productSlug,
    productName,
    imageUrl,
    unitBase,
    modifiers,
    includedNames,
    quantity,
  ];
}
