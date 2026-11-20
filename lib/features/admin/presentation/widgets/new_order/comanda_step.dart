import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../home/domain/entities/catalog_product.dart';
import '../../../../home/presentation/widgets/signature_strip.dart';
import '../../cubit/admin_new_order_cubit.dart';
import '../../cubit/admin_new_order_state.dart';
import '../admin_chip_band.dart';
import '../admin_filter_chip.dart';
import 'item_customize_sheet.dart';
import 'new_order_title.dart';
import 'product_pick_row.dart';

/// Paso 1 de la comanda (§042): título naciente (scrollea) +
/// banda de categorías FIJADA arriba — mismo layout del strip de
/// carriles de Cocina (§036): AdminChipBand negra full-width que
/// tapa la franja, chips AdminFilterChip centrados con conteo. La
/// lista stradlea la franja (kCardStripInset + blackZoneMargin —
/// el bloque centrado de todas las pantallas). Tap de producto →
/// ItemCustomizeSheet que produce el CartItem; si el producto ya
/// tiene unidades, la fila muestra el stepper rápido − N + (el +
/// repite la última config; otra personalización se pide tocando
/// la fila).
class ComandaStep extends StatelessWidget {
  const ComandaStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final state = context.watch<AdminNewOrderCubit>().state;
    // Misma estructura del kanban (§036): el título vive en el
    // header que colapsa y la banda queda fijada como fila del
    // body — el scroll de productos pasa por debajo de ella.
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(child: NewOrderTitle(text: l10n.adminNewOrderTitle)),
      ],
      body: Column(
        children: [
          _CategoryStrip(state: state),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final products = state.visibleProducts;
                if (products.isEmpty) {
                  // Categoría sin productos (o carta vacía) — el
                  // texto vive en zona negra como todo label plano
                  // (revisor-ui §042: sin estado vacío quedaba un
                  // hueco negro mudo).
                  return Padding(
                    padding: EdgeInsets.only(
                      left: c.maxWidth * kSignatureStripFraction + 16,
                      right: 16,
                      top: 24,
                    ),
                    child: Text(
                      l10n.adminNewOrderEmpty,
                      style: text.bodyMedium?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  // Straddle de la familia (§042, decisión del dueño):
                  // la IMAGEN queda centrada sobre el límite
                  // mostaza/negro (mitad y mitad, como la card que
                  // desborda) y el TEXTO vive completo en zona negra
                  // — nada se imprime sobre mostaza. El margen
                  // derecho iguala el bloque (blackZoneMargin).
                  padding: EdgeInsets.only(
                    left:
                        c.maxWidth * kSignatureStripFraction -
                        kPickRowImageSize / 2,
                    right: blackZoneMargin(c.maxWidth),
                    top: 4,
                    bottom: 24,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, i) {
                    final p = products[i];
                    return Column(
                      children: [
                        ProductPickRow(
                          product: p,
                          units: state.productUnits(p.id),
                          onTap: () => _openSheet(context, p),
                          onAddUnit: () => _bumpLastItem(context, p, 1),
                          onRemoveUnit: () => _bumpLastItem(context, p, -1),
                        ),
                        // El hairline solo vive en zona negra (sobre
                        // mostaza sería una línea cruzando la franja)
                        // y solo ENTRE filas — tras la última queda
                        // una línea colgando (revisor-ui §042).
                        if (i < products.length - 1)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: kPickRowImageSize + 4,
                            ),
                            child: Divider(
                              height: 1,
                              color: colors.outlineVariant.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Fila/producto tap → sheet de personalización; el CartItem que
  /// devuelve entra al borrador por `addItem` (merge incluido).
  Future<void> _openSheet(BuildContext context, CatalogProduct p) async {
    final item = await ItemCustomizeSheet.show(context, p);
    if (item != null && context.mounted) {
      context.read<AdminNewOrderCubit>().addItem(item);
    }
  }

  /// ± del stepper de la fila — opera sobre la ÚLTIMA fila del
  /// ticket con ese producto (la recién agregada = la que el dueño
  /// corrige); en 0 la fila se elimina sola (setItemQty<=0).
  void _bumpLastItem(BuildContext context, CatalogProduct p, int delta) {
    final items = context.read<AdminNewOrderCubit>().state.items;
    for (var i = items.length - 1; i >= 0; i--) {
      if (items[i].productId == p.id) {
        context.read<AdminNewOrderCubit>().setItemQty(
          items[i].id,
          items[i].quantity + delta,
        );
        return;
      }
    }
  }
}

/// Banda de categorías fijada (§042) — AdminChipBand compartida
/// con el strip de carriles de Cocina: chips centrados con conteo
/// (nº de productos por categoría; "Todo" = toda la carta).
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.state});

  final AdminNewOrderState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = state.categories.fold<int>(
      0,
      (s, c) => s + c.products.length,
    );
    return AdminChipBand(
      children: [
        AdminFilterChip(
          label: l10n.adminNewOrderCategoryAll,
          count: total,
          selected: state.selectedCategorySlug == null,
          onTap: () => context.read<AdminNewOrderCubit>().selectCategory(null),
        ),
        for (final cat in state.categories) ...[
          const SizedBox(width: 8),
          AdminFilterChip(
            label: cat.name,
            count: cat.products.length,
            selected: state.selectedCategorySlug == cat.slug,
            onTap: () =>
                context.read<AdminNewOrderCubit>().selectCategory(cat.slug),
          ),
        ],
      ],
    );
  }
}
