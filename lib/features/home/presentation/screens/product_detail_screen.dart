import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../data/catalog_mock.dart';
import '../widgets/customization_section.dart';
import '../widgets/product_image.dart';
import '../widgets/signature_strip.dart';

/// Detalle + personalización del producto (§018 — fase presentación).
///
/// Modelo decidido por el usuario: pan y salchicha son FIJOS (no se
/// quitan); los ingredientes propios se pueden quitar; los ingredientes
/// de OTROS productos se agregan como adicionales con precio propio;
/// toppings y salsas son gratis e ilimitados (sí/no, sin cantidades).
/// Total = base + Σ adicionales. El CTA es provisional (toast).
///
/// Lenguaje: la firma mostaza corre full-height como en el catálogo;
/// el producto encabeza en una straddle_card con su imagen flotante y
/// cada sección de personalización es otra card a caballo del límite.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({required this.item, super.key});

  final CatalogItem item;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final Set<String> _removed = {};
  final Set<String> _extras = {};
  final Set<String> _toppings = {};
  final Set<String> _sauces = {};

  int get _total {
    var t = widget.item.priceCop;
    for (final i in ingredientCatalog) {
      if (_extras.contains(i.id)) t += i.additionalPrice;
    }
    return t;
  }

  void _toggle(Set<String> s, String id) =>
      setState(() => s.contains(id) ? s.remove(id) : s.add(id));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final item = widget.item;
    final own = ingredientesOf(item);
    final extras = adicionalesFor(item);
    return Scaffold(
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // Nombre Anton mostaza NACIENDO de la franja —
                    // mismo motivo que el título de categoría
                    // (widthFactor 0.602 calibrado por el usuario).
                    // DENTRO del scroll (decisión del usuario): sale
                    // de pantalla al bajar; la flecha queda fija.
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
                              item.name,
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
                    _ProductHeaderCard(item: item),
                    if (own.isNotEmpty)
                      CustomizationSection(
                        title: l10n.detailSectionRemove,
                        children: [
                          for (final i in own)
                            RemovableRow(
                              label: i.name,
                              removed: _removed.contains(i.id),
                              onTap: () => _toggle(_removed, i.id),
                            ),
                        ],
                      ),
                    CustomizationSection(
                      title: l10n.detailSectionExtras,
                      children: [
                        for (final i in extras)
                          OptionRow(
                            label: i.name,
                            trailingLabel: '+${formatCop(i.additionalPrice)}',
                            selected: _extras.contains(i.id),
                            onTap: () => _toggle(_extras, i.id),
                          ),
                      ],
                    ),
                    CustomizationSection(
                      title: l10n.detailSectionToppings,
                      tag: l10n.detailFreeTag,
                      children: [
                        ChipWrap(
                          children: [
                            for (final t in toppingCatalog)
                              SelectChip(
                                label: t,
                                selected: _toppings.contains(t),
                                onTap: () => _toggle(_toppings, t),
                              ),
                          ],
                        ),
                      ],
                    ),
                    CustomizationSection(
                      title: l10n.detailSectionSauces,
                      tag: l10n.detailFreeTag,
                      children: [
                        ChipWrap(
                          children: [
                            for (final s in sauceCatalog)
                              SelectChip(
                                label: s,
                                selected: _sauces.contains(s),
                                onTap: () => _toggle(_sauces, s),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // Footer fijo — total dinámico + CTA (aprobado §018).
              // Fondo opaco: la franja no se filtra debajo (el "Total"
              // crema y el botón mostaza se camuflaban).
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.outlineVariant)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.detailTotalLabel,
                              style: text.bodySmall?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            Text(
                              formatCop(_total),
                              style: text.titleMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                AppToast.info(context, l10n.comingSoon),
                            child: Text(l10n.detailAddToCart),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Flecha back oscura SOBRE la franja — como la de categoría
          // (decisión del usuario): fija a 12 del tope del body, misma
          // fila que el título naciente.
          Positioned(
            top: 12,
            left: 4,
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: colors.onPrimary),
              tooltip: l10n.catalogBackTooltip,
              onPressed: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card del producto al tope del detalle (§018): la misma cuna
/// straddle que las cards de la lista pero más alta — la imagen flota
/// sobre el borde mostaza/negro y el texto abraza su borde derecho.
class _ProductHeaderCard extends StatelessWidget {
  const _ProductHeaderCard({required this.item});

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 150,
      child: LayoutBuilder(
        builder: (context, c) {
          final strip = c.maxWidth * kSignatureStripFraction;
          final imgSize = (c.maxHeight - 16) * 0.8;
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
                  color: colors.surfaceContainerHigh,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: imgSize - kFrameOverhang + kFrameTextGap,
                      right: 16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // El nombre va en el título naciente de la
                        // franja — la card lleva la composición (lo que
                        // trae) + precio.
                        Text(
                          item.ingredients,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatCop(item.priceCop),
                          style: text.titleMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
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
                  child: ProductImage(asset: item.imageAsset, size: imgSize),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
