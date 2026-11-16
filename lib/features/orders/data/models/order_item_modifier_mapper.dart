import '../../../cart/domain/entities/cart_modifier.dart';

/// Fila de modifier del OrderItemResponseDto → CartModifier (§016) —
/// group desde el slug del snapshot con las mismas reglas del detalle
/// del producto: removed y la fila del reemplazo siempre `ingredient`;
/// added por slug; null legacy → `extra` (fallback documentado).
CartModifier cartModifierFromOrderJson(Map<String, dynamic> m) {
  final action = m['action'] == 'added'
      ? CartModifierAction.added
      : CartModifierAction.removed;
  final replaces = m['replacesOptionId'] as String?;
  final groupSlug = m['modifierGroup'] as String?;
  final group = action == CartModifierAction.removed || replaces != null
      ? CartModifierGroup.ingredient
      : switch (groupSlug) {
          'toppings' => CartModifierGroup.topping,
          'sauces' => CartModifierGroup.sauce,
          _ => CartModifierGroup.extra,
        };
  return CartModifier(
    optionId: m['optionId'] as String? ?? '',
    optionName: m['optionName'] as String,
    action: action,
    priceDelta: m['priceDelta'] as int,
    replacesOptionId: replaces,
    group: group,
  );
}
