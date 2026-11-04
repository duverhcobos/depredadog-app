import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/catalog_product.dart';
import '../utils/catalog_assets.dart';
import '../utils/format_cop.dart';
import 'product_image.dart';
import 'signature_strip.dart';

/// Card de producto de la lista por categoría (§017 — franja al 40%):
/// la card nace dentro del mostaza y desborda al negro; el producto
/// flota sobre la franja cruzando el borde de la card. Nombre, tagline,
/// precio y "+" van en la zona negra. Tap y "+" abren el detalle de
/// personalización (§018 — todo es personalizable, decisión del usuario).
/// §019: `isAvailable=false` → tag "Agotado" en el slot del "+" y sin
/// tap — SIN atenuación (la translucidez la descartó el usuario; el
/// tag solo basta como señal).
class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.item,
    required this.categorySlug,
    super.key,
  });

  final CatalogProduct item;

  /// Slug de la categoría dueña — compone la ruta del detalle.
  final String categorySlug;

  void _openDetail(BuildContext context) =>
      context.push('/home/category/$categorySlug/product/${item.slug}');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 124,
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
                    onTap: item.isSellable ? () => _openDetail(context) : null,
                    child: Padding(
                      // Texto anclado al marco: borde del recuadro +
                      // 14 — sin restricción de zona negra (§017).
                      padding: EdgeInsets.only(
                        left:
                            (c.maxHeight - 16) * 0.8 -
                            kFrameOverhang +
                            kFrameTextGap,
                        right: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  item.tagline,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: colors.onSurface.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatCop(item.basePrice),
                                  style: text.titleSmall?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Hit area 48dp: círculo "+" navegable, o
                          // tag "Agotado" cuando no hay disponibilidad
                          // (§019 — mismo slot, sin tap; el tag toma
                          // su ancho natural, no el slot de 48).
                          SizedBox(
                            width: item.isSellable ? 48 : null,
                            height: 48,
                            child: item.isSellable
                                ? Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => _openDetail(context),
                                      child: Center(
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: colors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.add_rounded,
                                            size: 18,
                                            color: colors.onPrimary,
                                            semanticLabel:
                                                l10n.catalogAddTooltip,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.errorContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        l10n.catalogSoldOut,
                                        style: text.labelSmall?.copyWith(
                                          color: colors.onErrorContainer,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
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
                    asset: CatalogAssets.productAsset(item.slug),
                    imageUrl: item.imageUrl,
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
