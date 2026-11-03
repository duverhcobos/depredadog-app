import 'package:flutter/material.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../data/catalog_mock.dart';
import 'product_image.dart';
import 'signature_strip.dart';

/// Card hero del producto insignia (§017 — franja al 40%, dentro de la
/// lista Perros). Misma firma a caballo que las demás cards pero más
/// alta, con tag "EL DE LA CASA" + CTA provisional.
class HeroProductCard extends StatelessWidget {
  const HeroProductCard({required this.item, super.key});

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 160,
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
                  color: colors.surfaceContainerHigh,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () => AppToast.info(context, l10n.comingSoon),
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.homeFeaturedTag,
                            style: text.labelSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            item.tagline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: colors.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                formatCop(item.priceCop),
                                style: text.titleMedium?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                // Compacto — la card con margen
                                // simétrico deja la fila precio+CTA
                                // justa (§017).
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  minimumSize: const Size(0, 40),
                                ),
                                onPressed: () =>
                                    AppToast.info(context, l10n.comingSoon),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: Text(l10n.catalogAddTooltip),
                              ),
                            ],
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
                    asset: item.imageAsset,
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
