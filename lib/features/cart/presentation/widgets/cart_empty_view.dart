import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Carrito vacío (§020): ícono + título + CTA al menú — misma
/// composición que CatalogErrorView.
class CartEmptyView extends StatelessWidget {
  const CartEmptyView({required this.onBrowse, super.key});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono en primario: el vacío también habla Depredadog
            // (pulido revisor-estetico §020) — no un gris Material.
            Icon(
              Icons.shopping_cart_outlined,
              size: 44,
              color: colors.primary.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.cartEmptyTitle,
              textAlign: TextAlign.center,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.cartEmptySubtitle,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onBrowse,
              icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
              label: Text(l10n.cartEmptyCta),
            ),
          ],
        ),
      ),
    );
  }
}
