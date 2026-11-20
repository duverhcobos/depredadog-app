import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../home/presentation/utils/catalog_assets.dart';
import '../../../../home/presentation/utils/format_cop.dart';
import '../../../../home/presentation/widgets/product_image.dart';
import '../../../../home/domain/entities/catalog_product.dart';

/// Lado de la imagen de la fila del picker — constante compartida
/// con la comanda: la imagen queda CENTRADA sobre el borde
/// mostaza/negro, así que su mitad define el offset de la lista
/// (revisor-ui §042 — sin acoplamiento invisible).
const double kPickRowImageSize = 64;

/// Fila compacta del picker de la comanda (§042): imagen asset por
/// slug 64, nombre, precio y a la derecha "+" (sin unidades aún —
/// mismo gesto del tap de la fila: abre el sheet) o stepper − N +
/// cuando el producto ya está en el ticket (el + repite la última
/// configuración agregada; para otra personalización se toca la
/// fila). isSellable=false → tag "Agotado" en el slot de la acción
/// y sin tap SIN atenuar la fila (regla del catálogo §019).
class ProductPickRow extends StatelessWidget {
  const ProductPickRow({
    required this.product,
    required this.units,
    required this.onTap,
    required this.onAddUnit,
    required this.onRemoveUnit,
    super.key,
  });

  final CatalogProduct product;

  /// Unidades del producto ya en el ticket (todas las configs).
  final int units;

  /// Tap de la fila/botón "+" — abre el sheet de personalización.
  final VoidCallback onTap;

  /// + del stepper — repite la última config agregada (qty+1).
  final VoidCallback onAddUnit;

  /// − del stepper — baja una unidad de la última config (0 la quita).
  final VoidCallback onRemoveUnit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sellable = product.isSellable;
    return Semantics(
      label: '${product.name}, ${formatCop(product.basePrice)}',
      button: sellable,
      child: InkWell(
        onTap: sellable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              ProductImage(
                asset: CatalogAssets.productAsset(product.slug),
                imageUrl: product.imageUrl,
                size: kPickRowImageSize,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      formatCop(product.basePrice),
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              if (!sellable)
                // Tag "Agotado" §019 — misma píldora del catálogo
                // (errorContainer/onErrorContainer), sin atenuar la
                // fila (revisor-ui §042).
                Container(
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
                )
              else if (units == 0)
                // Círculo mostaza — affordance canónico "agregar"
                // del catálogo (product_card §019, eco revisor).
                IconButton(
                  onPressed: onTap,
                  tooltip: l10n.catalogAddTooltip,
                  icon: Container(
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
                    ),
                  ),
                )
              else
                _MiniStepper(
                  units: units,
                  onAdd: onAddUnit,
                  onRemove: onRemoveUnit,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stepper compacto del pick row — mismo espíritu del
/// QuantityStepper del carrito pero delgado (18dp el ícono) para
/// no inflar la fila; el hit de ± queda en 44dp reales como todo
/// lo interactivo de la casa (revisor-ui §042).
class _MiniStepper extends StatelessWidget {
  const _MiniStepper({
    required this.units,
    required this.onAdd,
    required this.onRemove,
  });

  final int units;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget button(IconData icon, VoidCallback onTap, String tooltip) =>
        SizedBox(
          height: 44,
          width: 44,
          child: IconButton(
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onTap,
            tooltip: tooltip,
            icon: Icon(icon, size: 18, color: colors.primary),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, onRemove, l10n.cartStepperRemove),
          Semantics(
            label: l10n.cartStepperQty(units),
            excludeSemantics: true,
            child: SizedBox(
              width: 24,
              child: Text(
                '$units',
                textAlign: TextAlign.center,
                style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          button(Icons.add_rounded, onAdd, l10n.cartStepperAdd),
        ],
      ),
    );
  }
}
