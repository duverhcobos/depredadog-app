import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/cart_modifier.dart';

/// Panel del desplegable del tile (§021b): el detalle del perro
/// organizado en las mismas secciones de la pantalla de
/// personalización — Ingredientes (lo que quedó), Se le quitó,
/// Adicionales, Toppings y Salsas — cada ítem con su punto mostaza,
/// y el botón Editar que abre el detalle en modo edición
/// (/home/cart/edit).
class CartItemDetailPanel extends StatelessWidget {
  const CartItemDetailPanel({required this.item, super.key});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Título de sección: el tratamiento Anton mostaza de las
    // secciones del detalle ("¿Se le quita algo?") un paso más
    // pequeño — decisión del usuario §021b.
    final header = text.titleSmall?.copyWith(
      color: colors.primary,
      fontWeight: FontWeight.w800,
    );
    final value = text.bodySmall?.copyWith(
      color: colors.onSurface.withValues(alpha: 0.8),
    );
    // El reemplazo gratis se comunica en "Se le quitó" como vínculo
    // "agotado → reemplazo" (revisor-ui §021) — por eso sus filas
    // `added` con replacesOptionId no repiten nombre en Adicionales.
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
                          // en toda la familia (pulido §021).
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
          // Borde defensivo: ítem sin snapshot ni modifiers → el
          // panel no queda desnudo (cae solo el botón Editar).
          if (item.includedNames.isEmpty && item.modifiers.isEmpty)
            Text(l10n.cartItemAsIs, style: value),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  context.push(AuthGuard.cartEditRoute, extra: item),
              icon: Icon(Icons.edit_outlined, size: 16, color: colors.primary),
              label: Text(
                l10n.cartItemEdit,
                style: text.bodySmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sección del panel: título Anton mostaza + ítems con punto
  /// primary (sangría francesa — el texto envuelve bajo el texto,
  /// no bajo el punto).
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
