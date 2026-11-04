import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/catalog_product.dart';
import '../../domain/entities/modifier_option.dart';
import '../cubit/catalog_cubit.dart';
import '../cubit/catalog_state.dart';
import '../utils/catalog_assets.dart';
import '../utils/format_cop.dart';
import '../widgets/catalog_states.dart';
import '../widgets/customization_section.dart';
import '../widgets/product_image.dart';
import '../widgets/signature_strip.dart';

/// Detalle + personalización del producto (§018 + integración §019).
///
/// El producto se resuelve del CatalogCubit por `productSlug` (refresh
/// silencioso al entrar). Las selecciones viven en el State como sets
/// de `option.id` del backend — quitados/adicionales/toppings/salsas.
/// Total = basePrice + Σ extraPrice de adicionales. Opción agotada →
/// fila gris inerte; producto agotado → CTA "Agotado" deshabilitado.
/// El CTA sigue provisional (toast) — el carrito es del módulo orders.
///
/// Lenguaje: la firma mostaza corre full-height como en el catálogo;
/// el producto encabeza en una straddle_card con su imagen flotante y
/// cada sección de personalización es otra card a caballo del límite.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({required this.productSlug, super.key});

  final String productSlug;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final Set<String> _removed = {};
  final Set<String> _extras = {};
  final Set<String> _toppings = {};
  final Set<String> _sauces = {};

  /// Ingrediente incluido agotado → id del adicional elegido como
  /// reemplazo gratis (1:1 — solo el agotado habilita el cambio,
  /// §019). `_swapOpen` = qué filas tienen el picker desplegado.
  final Map<String, String> _replacements = {};
  final Set<String> _swapOpen = {};

  /// Producto resuelto del último estado del cubit (cache del build —
  /// `_total` lo usa sin recorrer las categorías de nuevo).
  CatalogProduct? _item;

  int get _total {
    var t = _item?.basePrice ?? 0;
    for (final o in _item?.additionalOptions ?? const <ModifierOption>[]) {
      if (_extras.contains(o.id)) t += o.extraPrice;
    }
    return t;
  }

  CatalogProduct? _findProduct(CatalogState state) {
    for (final c in state.categories) {
      for (final p in c.products) {
        if (p.slug == widget.productSlug) return p;
      }
    }
    return null;
  }

  void _toggle(Set<String> s, String id) =>
      setState(() => s.contains(id) ? s.remove(id) : s.add(id));

  void _toggleSwap(String optionId) => setState(
    () => _swapOpen.contains(optionId)
        ? _swapOpen.remove(optionId)
        : _swapOpen.add(optionId),
  );

  /// Adicionales ofrecibles como reemplazo gratis del agotado
  /// `exhaustedId` — disponibles, elegibles por el dueño
  /// (isReplacementEligible) y no ya tomados por OTRO agotado:
  /// un candidato no se puede escoger dos veces en el mismo perro.
  Iterable<ModifierOption> _swapCandidates(String exhaustedId) {
    return (_item?.additionalOptions ?? const <ModifierOption>[]).where(
      (e) =>
          e.isAvailable &&
          e.isReplacementEligible &&
          (_replacements[exhaustedId] == e.id ||
              !_replacements.containsValue(e.id)),
    );
  }

  /// Nombre del adicional elegido como reemplazo del agotado
  /// `optionId` — para el sufijo "→ X" en la fila colapsada.
  String _replacementName(String optionId) {
    final id = _replacements[optionId];
    for (final o in _item?.additionalOptions ?? const <ModifierOption>[]) {
      if (o.id == id) return o.name;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    context.read<CatalogCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return BlocBuilder<CatalogCubit, CatalogState>(
      builder: (context, state) {
        if (state.categories.isEmpty) {
          if (state.status == CatalogStatus.error) {
            return Scaffold(
              body: CatalogErrorView(
                onRetry: () => context.read<CatalogCubit>().refresh(),
              ),
            );
          }
          return const Scaffold(body: CatalogLoadingView());
        }
        final item = _item = _findProduct(state);
        if (item == null) {
          // Slug eliminado o desconocido tras un refresh — salida al
          // menú (misma composición que CatalogErrorView).
          return const Scaffold(body: _ProductUnavailableView());
        }
        final own = item.removableIngredients;
        final extras = item.additionalOptions;
        final toppings = item.toppingOptions;
        final sauces = item.sauceOptions;
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
                              for (final o in own) ...[
                                RemovableRow(
                                  label: o.name,
                                  removed: _removed.contains(o.id),
                                  enabled: o.isAvailable,
                                  // ↔ solo si el agotado admite cambio
                                  // (isReplaceable — salchicha no) y
                                  // hay al menos un reemplazo elegible.
                                  onSwap:
                                      !o.isAvailable &&
                                          o.isReplaceable &&
                                          (_swapCandidates(o.id).isNotEmpty ||
                                              _replacements[o.id] != null)
                                      ? () => _toggleSwap(o.id)
                                      : null,
                                  swapExpanded: _swapOpen.contains(o.id),
                                  swapLabel: l10n.detailSwapCta,
                                  onTap: () => _toggle(_removed, o.id),
                                ),
                                // Reemplazo elegido: fila propia bajo el
                                // agotado, sangrada + gancho ↳ para que
                                // se lea como hija del ingrediente de
                                // arriba (decisión del usuario) — colores
                                // de fila activa; tocarla reabre el
                                // picker para cambiarla.
                                if (!o.isAvailable &&
                                    !_swapOpen.contains(o.id) &&
                                    _replacements[o.id] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons
                                              .subdirectory_arrow_right_rounded,
                                          size: 16,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 2),
                                        Expanded(
                                          child: OptionRow(
                                            label: _replacementName(o.id),
                                            selected: true,
                                            onTap: () => _toggleSwap(o.id),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Picker de reemplazo gratis: los
                                // adicionales disponibles del perro,
                                // indentados bajo la fila agotada —
                                // expande/colapsa animado (AnimatedSize
                                // recorta en alto, top-anchored).
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  clipBehavior: Clip.hardEdge,
                                  child:
                                      !o.isAvailable && _swapOpen.contains(o.id)
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Solo adicionales que el
                                            // dueño permite regalar y
                                            // que otro agotado no tomó
                                            // ya (_swapCandidates).
                                            for (final r in _swapCandidates(
                                              o.id,
                                            ))
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 12,
                                                ),
                                                child: OptionRow(
                                                  label: r.name,
                                                  selected:
                                                      _replacements[o.id] ==
                                                      r.id,
                                                  // Elegir colapsa el
                                                  // picker; retocar la
                                                  // elegida la des-selecciona
                                                  // y queda abierto para
                                                  // elegir otra.
                                                  onTap: () => setState(() {
                                                    if (_replacements[o.id] ==
                                                        r.id) {
                                                      _replacements.remove(
                                                        o.id,
                                                      );
                                                    } else {
                                                      _replacements[o.id] =
                                                          r.id;
                                                      _swapOpen.remove(o.id);
                                                    }
                                                  }),
                                                ),
                                              ),
                                          ],
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ],
                          ),
                        CustomizationSection(
                          title: l10n.detailSectionExtras,
                          children: [
                            for (final o in extras)
                              OptionRow(
                                label: o.name,
                                trailingLabel: o.isAvailable
                                    ? '+${formatCop(o.extraPrice)}'
                                    : l10n.catalogSoldOut,
                                selected: _extras.contains(o.id),
                                enabled: o.isAvailable,
                                onTap: () => _toggle(_extras, o.id),
                              ),
                          ],
                        ),
                        if (toppings.isNotEmpty)
                          CustomizationSection(
                            title: l10n.detailSectionToppings,
                            children: [
                              ChipWrap(
                                children: [
                                  for (final o in toppings)
                                    SelectChip(
                                      label: o.name,
                                      selected: _toppings.contains(o.id),
                                      enabled: o.isAvailable,
                                      onTap: () => _toggle(_toppings, o.id),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        if (sauces.isNotEmpty)
                          CustomizationSection(
                            title: l10n.detailSectionSauces,
                            children: [
                              ChipWrap(
                                children: [
                                  for (final o in sauces)
                                    SelectChip(
                                      label: o.name,
                                      selected: _sauces.contains(o.id),
                                      enabled: o.isAvailable,
                                      onTap: () => _toggle(_sauces, o.id),
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
                      border: Border(
                        top: BorderSide(color: colors.outlineVariant),
                      ),
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
                                    color: colors.onSurface.withValues(
                                      alpha: 0.7,
                                    ),
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
                              child: item.isSellable
                                  ? FilledButton(
                                      onPressed: () => AppToast.info(
                                        context,
                                        l10n.comingSoon,
                                      ),
                                      child: Text(l10n.detailAddToCart),
                                    )
                                  : FilledButton(
                                      onPressed: null,
                                      child: Text(l10n.catalogSoldOut),
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
      },
    );
  }
}

/// Vista inline "producto no disponible" (§019): se llegó con un slug
/// que ya no está en la carta (eliminado o refresh que lo sacó). Misma
/// composición que CatalogErrorView — ícono + título + CTA de salida.
class _ProductUnavailableView extends StatelessWidget {
  const _ProductUnavailableView();

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
            Icon(
              Icons.restaurant_outlined,
              size: 40,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.productUnavailableTitle,
              textAlign: TextAlign.center,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(l10n.productUnavailableCta),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card del producto al tope del detalle (§018): la misma cuna
/// straddle que las cards de la lista pero más alta — la imagen flota
/// sobre el borde mostaza/negro y el texto abraza su borde derecho.
/// §019: la composición es `ingredientsSummary` (defaults del grupo
/// ingredients del backend) y la imagen prefiere `imageUrl` remota.
class _ProductHeaderCard extends StatelessWidget {
  const _ProductHeaderCard({required this.item});

  final CatalogProduct item;

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
                          item.ingredientsSummary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatCop(item.basePrice),
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
                  child: ProductImage(
                    asset: CatalogAssets.productAsset(item.slug),
                    imageUrl: item.imageUrl,
                    size: imgSize,
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
