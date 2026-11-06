import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../cart/domain/entities/cart_item.dart';
import '../../../cart/domain/entities/cart_modifier.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../cart/presentation/widgets/cart_edit_scope_sheet.dart';
import '../../domain/entities/catalog_product.dart';
import '../../domain/entities/modifier_group.dart';
import '../../domain/entities/modifier_option.dart';
import '../cubit/catalog_cubit.dart';
import '../cubit/catalog_state.dart';
import '../utils/catalog_assets.dart';
import '../utils/detail_selections.dart';
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
/// El CTA agrega al CartCubit con la personalización actual y vuelve
/// a la carta (§020). Con `editingItem` no nulo entra en MODO EDICIÓN
/// (§021): las selecciones se precargan del CartItem y el CTA pasa a
/// "Guardar cambios" — qty>1 pregunta el alcance antes de guardar.
///
/// Lenguaje: la firma mostaza corre full-height como en el catálogo;
/// el producto encabeza en una straddle_card con su imagen flotante y
/// cada sección de personalización es otra card a caballo del límite.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    required this.productSlug,
    this.editingItem,
    super.key,
  });

  final String productSlug;

  /// Ítem del carrito en edición (§021) — null = modo agregar (§020).
  final CartItem? editingItem;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  /// Las 5 colecciones de selección del detalle en un solo valor
  /// (§021): removed/extras/toppings/sauces + replacements
  /// (ingrediente incluido agotado → id del adicional elegido como
  /// reemplazo gratis, 1:1 — solo el agotado habilita el cambio,
  /// §019). El modo edición las precarga desde el CartItem.
  DetailSelections _sel = DetailSelections();

  /// Qué filas agotadas tienen el picker de reemplazo desplegado —
  /// estado de UI suelto (no es selección: no viaja en _sel).
  final Set<String> _swapOpen = {};

  /// Prefill del modo edición ya aplicado — corre una sola vez,
  /// mid-build en el primer frame con el producto resuelto (§021).
  bool _prefilled = false;

  /// `context.pop()` de go_router bypassea PopScope (pop declarativo
  /// de la página — no consulta popDisposition); el PopScope solo
  /// cubre el back DEL SISTEMA (maybePop). Para la flecha la guardia
  /// de cambios sin guardar va manual aquí (revisor-ui §021).
  Future<void> _requestLeave(CatalogProduct item) async {
    if (widget.editingItem == null || !_isDirty(item)) {
      context.pop();
      return;
    }
    if (await _confirmDiscard() && mounted) context.pop();
  }

  /// Producto resuelto del último estado del cubit (cache del build —
  /// `_total` lo usa sin recorrer las categorías de nuevo).
  CatalogProduct? _item;

  int get _total {
    var t = _item?.basePrice ?? 0;
    for (final o in _item?.additionalOptions ?? const <ModifierOption>[]) {
      if (_sel.extras.contains(o.id)) t += o.extraPrice;
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
          (_sel.replacements[exhaustedId] == e.id ||
              !_sel.replacements.containsValue(e.id)),
    );
  }

  /// Nombre del adicional elegido como reemplazo del agotado
  /// `optionId` — para el sufijo "→ X" en la fila colapsada.
  String _replacementName(String optionId) {
    final id = _sel.replacements[optionId];
    for (final o in _item?.additionalOptions ?? const <ModifierOption>[]) {
      if (o.id == id) return o.name;
    }
    return '';
  }

  /// Resuelve una opción por id dentro de los grupos del producto —
  /// para los snapshots de nombre/precio del CartModifier.
  ModifierOption? _optionById(CatalogProduct item, String id) {
    for (final g in item.modifierGroups) {
      for (final o in g.options) {
        if (o.id == id) return o;
      }
    }
    return null;
  }

  /// Traduce las selecciones locales a filas CartModifier — el
  /// reemplazo gratis produce DOS filas (removed del agotado +
  /// added del reemplazo a 0 con `replacesOptionId` apuntando al
  /// agotado, §021), como en order_item_modifiers.
  List<CartModifier> _buildModifiers(CatalogProduct item) {
    CartModifier? mod(
      String id,
      CartModifierAction a, [
      int price = 0,
      String? replacesOptionId,
      CartModifierGroup group = CartModifierGroup.ingredient,
    ]) {
      final o = _optionById(item, id);
      if (o == null) return null;
      return CartModifier(
        optionId: o.id,
        optionName: o.name,
        action: a,
        priceDelta: price,
        replacesOptionId: replacesOptionId,
        group: group,
      );
    }

    return [
      // Elemento null-aware `?mod(...)` — omite la fila cuando la
      // opción no se resuelve por id (no debería pasar: los sets se
      // llenan desde las mismas opciones renderizadas). El filtro de
      // replacements blinda el duplicado si un id reemplazado cayera
      // en _removed (revisor-ui §021 — el par removed+added del
      // reemplazo ya lo cubre el loop de abajo).
      for (final id in _sel.removed)
        if (!_sel.replacements.containsKey(id))
          ?mod(id, CartModifierAction.removed),
      for (final e in _sel.replacements.entries) ...[
        ?mod(e.key, CartModifierAction.removed),
        ?mod(e.value, CartModifierAction.added, 0, e.key),
      ],
      for (final id in _sel.extras)
        ?mod(
          id,
          CartModifierAction.added,
          _optionById(item, id)?.extraPrice ?? 0,
          null,
          CartModifierGroup.extra,
        ),
      for (final id in _sel.toppings)
        ?mod(id, CartModifierAction.added, 0, null, CartModifierGroup.topping),
      for (final id in _sel.sauces)
        ?mod(id, CartModifierAction.added, 0, null, CartModifierGroup.sauce),
    ];
  }

  /// Ingredientes que quedan EN el ítem (§021): los includedByDefault
  /// del producto menos los quitados y los reemplazados — el snapshot
  /// "Lleva:" que muestra el desplegable del tile del carrito.
  List<String> _includedNames(CatalogProduct item) {
    final ingredients =
        item.groupBySlug(ModifierGroupSlugs.ingredients)?.options ??
        const <ModifierOption>[];
    return [
      for (final o in ingredients)
        if (o.includedByDefault &&
            !_sel.removed.contains(o.id) &&
            !_sel.replacements.containsKey(o.id))
          o.name,
    ];
  }

  /// Agrega el producto con su personalización al carrito (§020):
  /// toast de confirmación + vuelta a la carta — el caso común es
  /// seguir pidiendo cosas distintas (decisión del usuario).
  void _addToCart(CatalogProduct item) {
    final l10n = AppLocalizations.of(context)!;
    context.read<CartCubit>().addItem(
      productId: item.id,
      productSlug: item.slug,
      productName: item.name,
      imageUrl: item.imageUrl,
      unitBase: item.basePrice,
      modifiers: _buildModifiers(item),
      includedNames: _includedNames(item),
    );
    AppToast.success(context, l10n.cartItemAdded);
    context.pop();
  }

  /// ¿La configuración actual difiere del CartItem original? (§021)
  /// — misma clave que `sameConfiguration`: producto + set de
  /// modifiers. El PopScope la usa para pedir confirmación al
  /// salir y `_saveEdit` para no mentir el toast ni abrir el
  /// sheet cuando nada cambió.
  bool _isDirty(CatalogProduct item) {
    final editing = widget.editingItem;
    return editing != null &&
        !editing
            .copyWith(
              modifiers: _buildModifiers(item),
              includedNames: _includedNames(item),
            )
            .sameConfiguration(editing);
  }

  Future<bool> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.cartEditDiscardTitle),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cartEditDiscardStay),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.cartEditDiscardLeave),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Guarda la edición sobre el CartItem original (§021). Con qty>1
  /// pregunta el alcance (decisión del usuario) — el sheet devuelve
  /// true=a todas / false=solo 1 / null=cancelado. Sin cambios
  /// reales vuelve sin preguntar ni tostar "guardado" (revisor-ui).
  Future<void> _saveEdit(CatalogProduct item) async {
    final l10n = AppLocalizations.of(context)!;
    final editing = widget.editingItem!;
    final mods = _buildModifiers(item);
    final names = _includedNames(item);
    if (editing
        .copyWith(modifiers: mods, includedNames: names)
        .sameConfiguration(editing)) {
      context.pop();
      return;
    }
    var applyToAll = true;
    if (editing.quantity > 1) {
      final r = await showCartEditScopeSheet(
        context,
        quantity: editing.quantity,
      );
      if (r == null || !mounted) return;
      applyToAll = r;
    }
    final outcome = context.read<CartCubit>().editItem(
      itemId: editing.id,
      modifiers: mods,
      includedNames: names,
      applyToAll: applyToAll,
    );
    AppToast.success(
      context,
      outcome == CartEditOutcome.merged
          ? l10n.cartEditMerged
          : l10n.cartEditSaved,
    );
    // context.pop() bypassea el PopScope — sale directo.
    context.pop();
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
          // menú (misma composición que CatalogErrorView). En modo
          // edición el pop cae al CARRITO, no a la carta (revisor-ui).
          return Scaffold(
            body: _ProductUnavailableView(editing: widget.editingItem != null),
          );
        }
        // Prefill lazy del modo edición (§021): con el producto ya
        // resuelto se reconstruyen los 5 sets desde el CartItem —
        // mutación directa mid-build (se aplica al mismo frame, sin
        // setState) y corre una sola vez por pantalla.
        if (widget.editingItem != null && !_prefilled) {
          _sel = DetailSelections.fromCartItem(widget.editingItem!, item);
          _prefilled = true;
        }
        final editing = widget.editingItem != null;
        final own = item.removableIngredients;
        final extras = item.additionalOptions;
        final toppings = item.toppingOptions;
        final sauces = item.sauceOptions;
        // PopScope (§021): cubre el back DEL SISTEMA en modo edición
        // con cambios sin guardar — la flecha de la pantalla usa
        // _requestLeave porque context.pop() no consulta popDisposition.
        return PopScope(
          canPop: widget.editingItem == null || !_isDirty(item),
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (await _confirmDiscard() && context.mounted) {
              context.pop();
            }
          },
          child: Scaffold(
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
                                padding: const EdgeInsets.fromLTRB(
                                  0,
                                  12,
                                  16,
                                  0,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    // Cue de orientación del modo
                                    // edición (revisor-ui §021): si
                                    // no, la pantalla era idéntica a
                                    // la de agregar salvo el CTA.
                                    editing
                                        ? l10n.detailEditingTitle(item.name)
                                        : item.name,
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
                                    removed: _sel.removed.contains(o.id),
                                    enabled: o.isAvailable,
                                    // ↔ solo si el agotado admite cambio
                                    // (isReplaceable — salchicha no) y
                                    // hay al menos un reemplazo elegible.
                                    onSwap:
                                        !o.isAvailable &&
                                            o.isReplaceable &&
                                            (_swapCandidates(o.id).isNotEmpty ||
                                                _sel.replacements[o.id] != null)
                                        ? () => _toggleSwap(o.id)
                                        : null,
                                    swapExpanded: _swapOpen.contains(o.id),
                                    swapLabel: l10n.detailSwapCta,
                                    onTap: () => _toggle(_sel.removed, o.id),
                                  ),
                                  // Reemplazo elegido: fila propia bajo el
                                  // agotado, sangrada + gancho ↳ para que
                                  // se lea como hija del ingrediente de
                                  // arriba (decisión del usuario) — colores
                                  // de fila activa; tocarla reabre el
                                  // picker para cambiarla.
                                  if (!o.isAvailable &&
                                      !_swapOpen.contains(o.id) &&
                                      _sel.replacements[o.id] != null)
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
                                        !o.isAvailable &&
                                            _swapOpen.contains(o.id)
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
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 12,
                                                      ),
                                                  child: OptionRow(
                                                    label: r.name,
                                                    selected:
                                                        _sel.replacements[o
                                                            .id] ==
                                                        r.id,
                                                    // Elegir colapsa el
                                                    // picker; retocar la
                                                    // elegida la des-selecciona
                                                    // y queda abierto para
                                                    // elegir otra.
                                                    onTap: () => setState(() {
                                                      if (_sel.replacements[o
                                                              .id] ==
                                                          r.id) {
                                                        _sel.replacements
                                                            .remove(o.id);
                                                      } else {
                                                        _sel.replacements[o
                                                                .id] =
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
                                  selected: _sel.extras.contains(o.id),
                                  enabled: o.isAvailable,
                                  onTap: () => _toggle(_sel.extras, o.id),
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
                                        selected: _sel.toppings.contains(o.id),
                                        enabled: o.isAvailable,
                                        onTap: () =>
                                            _toggle(_sel.toppings, o.id),
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
                                        selected: _sel.sauces.contains(o.id),
                                        enabled: o.isAvailable,
                                        onTap: () => _toggle(_sel.sauces, o.id),
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
                                    // En edición con qty>1 el total es
                                    // POR UNIDAD — el sheet pregunta a
                                    // cuántos aplicar (revisor-ui §021).
                                    editing && widget.editingItem!.quantity > 1
                                        ? l10n.detailTotalPerUnitLabel
                                        : l10n.detailTotalLabel,
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
                                // En modo edición el CTA queda habilitado
                                // aunque el producto esté agotado — el
                                // ítem YA está en el carrito y la
                                // revalidación real es del backend al
                                // crear la orden (revisor-ui §021).
                                child: item.isSellable || editing
                                    ? FilledButton(
                                        // Modo edición (§021): guarda
                                        // sobre el CartItem; modo
                                        // agregar: nueva fila (§020).
                                        onPressed: () => editing
                                            ? _saveEdit(item)
                                            : _addToCart(item),
                                        child: Text(
                                          editing
                                              ? l10n.cartEditSaveCta
                                              : l10n.detailAddToCart,
                                        ),
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
                // fila que el título naciente. En edición pasa por la
                // guardia manual de cambios sin guardar (context.pop no
                // consulta el PopScope).
                Positioned(
                  top: 12,
                  left: 4,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: colors.onPrimary,
                    ),
                    tooltip: l10n.catalogBackTooltip,
                    onPressed: () => _requestLeave(item),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Vista inline "producto no disponible" (§019): se llegó con un slug
/// que ya no está en la carta (eliminado o refresh que lo sacó). Misma
/// composición que CatalogErrorView — ícono + título + CTA de salida.
/// §021: en modo edición el pop cae al carrito — el CTA lo dice.
class _ProductUnavailableView extends StatelessWidget {
  const _ProductUnavailableView({this.editing = false});

  final bool editing;

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
              label: Text(
                editing ? l10n.cartEditBackToCart : l10n.productUnavailableCta,
              ),
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
