import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../cart/domain/entities/cart_modifier.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../domain/entities/customer_order.dart';

/// Panel del desplegable del ítem del pedido (§023): el detalle del
/// perro en las mismas secciones del carrito — Ingredientes (lo que
/// quedó), Se le quitó, Adicionales, Toppings y Salsas — cada ítem
/// con su punto mostaza y el extra con su +precio. SIN "Editar":
/// el pedido ya se cobró, es solo lectura — el cliente viene acá a
/// verificar qué quedó adentro (decisión del usuario).
class OrderItemDetailPanel extends StatelessWidget {
  const OrderItemDetailPanel({required this.item, super.key});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Título de sección: el tratamiento Anton mostaza de las
    // secciones un paso más pequeño — idéntico al panel del carrito.
    final header = text.titleSmall?.copyWith(
      color: colors.primary,
      fontWeight: FontWeight.w800,
    );
    final value = text.bodySmall?.copyWith(
      color: colors.onSurface.withValues(alpha: 0.8),
    );
    // Reemplazo gratis: vínculo "agotado → reemplazo" dentro de
    // "Se le quitó" — la misma mecánica del panel del carrito.
    final replacementNames = {
      for (final m in item.modifiers)
        if (m.action == CartModifierAction.added && m.replacesOptionId != null)
          m.replacesOptionId!: m.optionName,
    };
    final removed = item.modifiers
        .where((m) => m.action == CartModifierAction.removed)
        .map((m) {
          final r = replacementNames[m.optionId];
          return r == null ? m.optionName : '${m.optionName} → $r';
        })
        .toList();
    List<CartModifier> addedOf(CartModifierGroup? group) => item.modifiers
        .where(
          (m) =>
              m.action == CartModifierAction.added &&
              m.replacesOptionId == null &&
              (m.group ?? CartModifierGroup.extra) == group,
        )
        .toList();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.includedNames.isNotEmpty)
            _section(
              title: l10n.cartDetailIngredients,
              items: [
                for (final name in item.includedNames) Text(name, style: value),
              ],
              header: header,
              colors: colors,
            ),
          if (removed.isNotEmpty)
            _section(
              title: l10n.cartDetailRemoved,
              items: [for (final name in removed) Text(name, style: value)],
              header: header,
              colors: colors,
            ),
          for (final (title, group) in [
            (l10n.cartDetailExtras, CartModifierGroup.extra),
            (l10n.cartDetailToppings, CartModifierGroup.topping),
            (l10n.cartDetailSauces, CartModifierGroup.sauce),
          ])
            if (addedOf(group).isNotEmpty)
              _section(
                title: title,
                items: [
                  for (final m in addedOf(group))
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: m.optionName, style: value),
                          // El precio del extra canta en mostaza como
                          // en toda la familia.
                          if (m.priceDelta > 0)
                            TextSpan(
                              text: ' +${formatCop(m.priceDelta)}',
                              style: value?.copyWith(color: colors.primary),
                            ),
                        ],
                      ),
                    ),
                ],
                header: header,
                colors: colors,
              ),
          // Ítem sin personalización ni snapshot → panel no desnudo.
          if (item.includedNames.isEmpty && item.modifiers.isEmpty)
            Text(l10n.cartItemAsIs, style: value),
        ],
      ),
    );
  }

  /// Sección del panel: título Anton mostaza + ítems con punto
  /// primary (sangría francesa — el texto envuelve bajo el texto,
  /// no bajo el punto). Idéntica a la del panel del carrito.
  Widget _section({
    required String title,
    required List<Widget> items,
    required TextStyle? header,
    required ColorScheme colors,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: header),
          const SizedBox(height: 4),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    // Alinea el punto con la primera línea del texto.
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: item),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
