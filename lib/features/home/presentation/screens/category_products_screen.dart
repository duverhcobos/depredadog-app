import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../data/catalog_mock.dart';
import '../widgets/hero_product_card.dart';
import '../widgets/product_card.dart';
import '../widgets/product_image.dart';
import '../widgets/signature_strip.dart';

/// Lista de productos de una categoría (§017 — hija de /home por push).
/// Franja mostaza al 40% (continuidad de la firma del home) + flecha de
/// regreso + nombre de la categoría + cards a caballo de la franja con
/// el producto flotando sobre el límite. El Depredador encabeza Perros
/// como hero (decisión del usuario).
class CategoryProductsScreen extends StatelessWidget {
  const CategoryProductsScreen({required this.category, super.key});

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
    final items = catalogMockItems
        .where((i) => i.category == category)
        .toList();
    return Scaffold(
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Encabezado — nombre Anton mostaza que NACE de la
              // franja: el borde de la caja apenas entra al mostaza
              // (mismo color → el filo de la primera letra se funde y
              // el texto parece emerger de la firma — punto exacto
              // calibrado por el usuario). Va DENTRO del scroll
              // (decisión del usuario): sale de pantalla al bajar; la
              // flecha queda fija aparte (Positioned). Align externo:
              // dentro del ListView el FractionallySizedBox solo
              // recibe restricción suelta y caería a la izquierda.
              Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.602,
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _label(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.headlineSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (category == CatalogCategory.dogs)
                const HeroProductCard(item: depredadorItem),
              if (items.isEmpty)
                // Cupo fantasma a caballo: la misma cuna que una
                // card de producto (card nace en la franja, cover
                // cruza el límite, textos en el eje universal) pero
                // sin affordance — el gesto persiste aun sin
                // productos y la franja no corre vacía.
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.55,
                  child: Center(
                    child: SizedBox(
                      height: 144,
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final strip = c.maxWidth * kSignatureStripFraction;
                          return Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              Positioned(
                                left: strip * kCardStripInset,
                                top: 8,
                                bottom: 8,
                                right: blackZoneMargin(c.maxWidth),
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  color: colors.surfaceContainerLow,
                                  clipBehavior: Clip.antiAlias,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      left:
                                          (c.maxHeight - 16) * 0.8 -
                                          kFrameOverhang +
                                          kFrameTextGap,
                                      right: 16,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.comingSoon,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: text.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          l10n.catalogEmptySubtitle,
                                          style: text.bodySmall?.copyWith(
                                            color: colors.onSurface.withValues(
                                              alpha: 0.6,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
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
                    ),
                  ),
                )
              else
                for (final item in items)
                  if (item != depredadorItem ||
                      category != CatalogCategory.dogs)
                    ProductCard(item: item),
            ],
          ),
          // Flecha de regreso SOBRE la franja mostaza (§017 — decisión
          // del usuario): fija en el Stack — NO entra al scroll; el
          // título sí (primer ítem del ListView).
          Positioned(
            top: 12,
            left: 4,
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              tooltip: l10n.catalogBackTooltip,
              onPressed: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }
}
