import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../l10n/app_localizations.dart';
import '../data/catalog_mock.dart';
import 'product_image.dart';
import 'signature_strip.dart';

/// Card de categoría del selector del home (§017 — franja al 40%):
/// la card nace DENTRO de la franja mostaza y desborda hacia el negro;
/// la imagen del producto flota sobre el mostaza cruzando el borde de
/// la card. Nombre + conteo honesto + chevron sobre la zona negra.
/// Navega con push a /home/category/{segment}.
class CategoryCard extends StatelessWidget {
  const CategoryCard({required this.category, super.key});

  final CatalogCategory category;

  String _label(AppLocalizations l10n) => switch (category) {
    CatalogCategory.dogs => l10n.catalogCategoryDogs,
    CatalogCategory.more => l10n.catalogCategoryMore,
    CatalogCategory.drinks => l10n.catalogCategoryDrinks,
    CatalogCategory.combos => l10n.catalogCategoryCombos,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final count = catalogCountOf(category);
    return SizedBox(
      height: 116,
      child: LayoutBuilder(
        builder: (context, c) {
          final strip = c.maxWidth * kSignatureStripFraction;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Card a caballo — nace dentro del mostaza (60% de la
              // franja) y desborda hacia el negro hasta el borde.
              Positioned(
                left: strip * kCardStripInset,
                top: 8,
                bottom: 8,
                // Margen derecho = sobrante del marco a la izquierda —
                // el conjunto card+recuadro queda centrado (§017).
                right: blackZoneMargin(c.maxWidth),
                child: Card(
                  margin: EdgeInsets.zero,
                  color: colors.surfaceContainerLow,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    onTap: () => context.push(
                      '${AuthGuard.homeRoute}/category/${category.segment}',
                    ),
                    child: Padding(
                      // Texto anclado al marco: borde del recuadro +
                      // 14 — sin restricción de zona negra (§017).
                      padding: EdgeInsets.only(
                        left:
                            (c.maxHeight - 16) * 0.8 -
                            kFrameOverhang +
                            kFrameTextGap,
                        right: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _label(l10n),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  count > 0
                                      ? l10n.catalogProductsCount(count)
                                      : l10n.comingSoon,
                                  style: text.bodySmall?.copyWith(
                                    color: colors.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Recuadro crema a caballo del borde de la card —
              // 80% del alto de la card, imagen al 90% interna (§017).
              Positioned(
                left: strip * kCardStripInset - kFrameOverhang,
                child: IgnorePointer(
                  child: ProductImage(
                    asset: category.coverAsset,
                    size: (c.maxHeight - 16) * 0.8,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
