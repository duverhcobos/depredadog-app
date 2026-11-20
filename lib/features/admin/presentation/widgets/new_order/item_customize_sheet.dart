import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../cart/domain/entities/cart_item.dart';
import '../../../../cart/domain/entities/cart_modifier.dart';
import '../../../../cart/presentation/widgets/quantity_stepper.dart';
import '../../../../home/domain/entities/catalog_product.dart';
import '../../../../home/domain/entities/modifier_group.dart';
import '../../../../home/domain/entities/modifier_option.dart';
import '../../../../home/presentation/utils/catalog_assets.dart';
import '../../../../home/presentation/utils/format_cop.dart';
import '../../../../home/presentation/widgets/customization_section.dart';
import '../../../../home/presentation/widgets/product_image.dart';

/// Sheet de personalización de la comanda (§042): header
/// (foto+nombre+precio) + qty stepper + las mismas secciones del
/// detalle del cliente — "¿Se le quita algo?" (RemovableRow de
/// removableIngredients), "¿Le agregamos algo más?" (OptionRow de
/// additionalOptions con +$), Toppings/Salsas (SelectChip gratis)
/// solo cuando el producto las tiene. Opción agotada → fila
/// deshabilitada con tag "Agotado" (V1 sin flujo de reemplazo —
/// fuera de alcance §042). Nota del ítem FUERA de scope
/// (items[].notes no viaja en V1). "Agregar · $X.XXX" produce el
/// CartItem y cierra.
class ItemCustomizeSheet extends StatefulWidget {
  const ItemCustomizeSheet({required this.product, super.key});

  final CatalogProduct product;

  /// Modal isScrollControlled — devuelve el CartItem armado o null
  /// si se cerró sin agregar. Lenguaje del hermano
  /// cart_edit_scope_sheet: surfaceContainerLow + radio 16.
  static Future<CartItem?> show(BuildContext context, CatalogProduct p) {
    return showModalBottomSheet<CartItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ItemCustomizeSheet(product: p),
    );
  }

  @override
  State<ItemCustomizeSheet> createState() => _ItemCustomizeSheetState();
}

class _ItemCustomizeSheetState extends State<ItemCustomizeSheet> {
  /// Selecciones del sheet — espejo de DetailSelections del detalle
  /// SIN replacements (V1: el agotado solo se muestra, no se cambia,
  /// §042 fuera de alcance).
  final Set<String> _removed = {};
  final Set<String> _extras = {};
  final Set<String> _toppings = {};
  final Set<String> _sauces = {};
  int _qty = 1;

  void _toggle(Set<String> s, String id) =>
      setState(() => s.contains(id) ? s.remove(id) : s.add(id));

  /// Total del CTA — (base + adicionales) × unidades.
  int get _total {
    var t = widget.product.basePrice;
    for (final o in widget.product.additionalOptions) {
      if (_extras.contains(o.id)) t += o.extraPrice;
    }
    return t * _qty;
  }

  /// Resuelve una opción por id dentro de los grupos del producto —
  /// para los snapshots de nombre/precio del CartModifier.
  ModifierOption? _optionById(String id) {
    for (final g in widget.product.modifierGroups) {
      for (final o in g.options) {
        if (o.id == id) return o;
      }
    }
    return null;
  }

  /// Traduce las selecciones a filas CartModifier — misma
  /// composición del detalle del cliente (quitados → adicionales →
  /// toppings → salsas; sin filas de reemplazo en V1, §042).
  List<CartModifier> _buildModifiers() {
    CartModifier? mod(
      String id,
      CartModifierAction a, [
      int price = 0,
      CartModifierGroup group = CartModifierGroup.ingredient,
    ]) {
      final o = _optionById(id);
      if (o == null) return null;
      return CartModifier(
        optionId: o.id,
        optionName: o.name,
        action: a,
        priceDelta: price,
        group: group,
      );
    }

    return [
      for (final id in _removed) ?mod(id, CartModifierAction.removed),
      for (final id in _extras)
        ?mod(
          id,
          CartModifierAction.added,
          _optionById(id)?.extraPrice ?? 0,
          CartModifierGroup.extra,
        ),
      for (final id in _toppings)
        ?mod(id, CartModifierAction.added, 0, CartModifierGroup.topping),
      for (final id in _sauces)
        ?mod(id, CartModifierAction.added, 0, CartModifierGroup.sauce),
    ];
  }

  /// Ingredientes que quedan EN el ítem — el snapshot "Lleva:" del
  /// desplegable del tile (misma regla del detalle §021).
  List<String> _includedNames() {
    final ingredients =
        widget.product.groupBySlug(ModifierGroupSlugs.ingredients)?.options ??
        const <ModifierOption>[];
    return [
      for (final o in ingredients)
        if (o.includedByDefault && !_removed.contains(o.id)) o.name,
    ];
  }

  void _add() {
    final p = widget.product;
    Navigator.of(context).pop(
      CartItem(
        // id vacío — el cubit le asigna `comanda-<n>` en el merge.
        id: '',
        productId: p.id,
        productSlug: p.slug,
        productName: p.name,
        imageUrl: p.imageUrl,
        unitBase: p.basePrice,
        modifiers: _buildModifiers(),
        includedNames: _includedNames(),
        quantity: _qty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final p = widget.product;
    final removable = p.removableIngredients;
    final extras = p.additionalOptions;
    final toppings = p.toppingOptions;
    final sauces = p.sauceOptions;
    return SafeArea(
      // Techo 85% — la columna abraza su contenido cuando es corta
      // y scrollea cuando lo desborda; el CTA queda PINEADO fuera
      // del scroll (revisor-ui §042: antes era el último hijo del
      // scroll y en productos con muchas opciones caía bajo el fold).
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          // El sheet sube con el teclado (nota futura — hoy no hay
          // campo de texto, queda la regla por si llega).
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Header: foto + nombre + precio + stepper de unidades.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            ProductImage(
                              asset: CatalogAssets.productAsset(p.slug),
                              imageUrl: p.imageUrl,
                              size: 64,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    formatCop(p.basePrice),
                                    style: text.bodySmall?.copyWith(
                                      color: colors.onSurface.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            QuantityStepper(
                              quantity: _qty,
                              onChanged: (q) =>
                                  setState(() => _qty = q.clamp(1, 20)),
                            ),
                          ],
                        ),
                      ),
                      // Secciones compactas — mismos conceptos del cliente.
                      if (removable.isNotEmpty)
                        _SheetSection(
                          title: l10n.detailSectionRemove,
                          children: [
                            for (final o in removable)
                              RemovableRow(
                                label: o.name,
                                removed: _removed.contains(o.id),
                                enabled: o.isAvailable,
                                onTap: () => _toggle(_removed, o.id),
                              ),
                          ],
                        ),
                      if (extras.isNotEmpty)
                        _SheetSection(
                          title: l10n.detailSectionExtras,
                          children: [
                            for (final o in extras)
                              OptionRow(
                                label: o.name,
                                selected: _extras.contains(o.id),
                                enabled: o.isAvailable,
                                trailingLabel: !o.isAvailable
                                    ? l10n.catalogSoldOut
                                    : o.extraPrice > 0
                                    ? '+${formatCop(o.extraPrice)}'
                                    : null,
                                onTap: () => _toggle(_extras, o.id),
                              ),
                          ],
                        ),
                      if (toppings.isNotEmpty)
                        _SheetSection(
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
                        _SheetSection(
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
                    ],
                  ),
                ),
              ),
              // Footer pineado (patrón §035 — superficie opaca +
              // hairline): "Agregar · $X.XXX" produce el CartItem
              // y cierra. Siempre visible — no baja con el scroll.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.outlineVariant)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _add,
                      child: Text(
                        '${l10n.adminNewOrderSheetAdd} · ${formatCop(_total)}',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sección compacta del sheet — título mostaza + rows, sin el
/// straddle de CustomizationSection (el sheet no tiene franja).
class _SheetSection extends StatelessWidget {
  const _SheetSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              title,
              style: text.titleSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
