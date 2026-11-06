import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/catalog_assets.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../../home/presentation/widgets/product_image.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../domain/entities/cart_item.dart';
import 'cart_item_detail_panel.dart';
import 'quantity_stepper.dart';

/// Fila del carrito (§020 + pulido): card straddle de la familia —
/// nace a la derecha de la franja y la imagen flota a caballo de su
/// borde izquierdo (mismo gesto firma que las product cards).
/// Nombre en Anton, stepper, eliminar y total de línea.
///
/// El chip "Detalle" junto al nombre despliega el panel por
/// secciones (§021b — el resumen de modificadores bajo el título se
/// retiró por decisión del usuario; el chevron vive dentro del chip).
/// El unitPrice solo se muestra cuando quantity > 1 — con una
/// unidad duplicaba el lineTotal (revisor-ui §020).
class CartItemTile extends StatefulWidget {
  const CartItemTile({
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
    super.key,
  });

  final CartItem item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  State<CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<CartItemTile> {
  /// Detalle desplegado por tap — arranca colapsado (§021).
  bool _expanded = false;

  /// Alto del recuadro flotante — 80px: protagonismo de la foto sin
  /// inflar la card (pulido revisor-estetico §020).
  static const double _imageSize = 80;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, c) {
          final cardLeft =
              c.maxWidth * kSignatureStripFraction * kCardStripInset;
          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: cardLeft,
                  right: blackZoneMargin(c.maxWidth),
                ),
                child: Card(
                  margin: EdgeInsets.zero,
                  color: colors.surfaceContainerLow,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    // Texto anclado al marco: borde derecho del
                    // recuadro + gap (misma regla que product_card).
                    padding: const EdgeInsets.only(
                      left: _imageSize - kFrameOverhang + kFrameTextGap,
                      right: 14,
                      top: 12,
                      bottom: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  // Solo con qty>1: con 1 duplicaba
                                  // el lineTotal (revisor-ui §020).
                                  if (item.quantity > 1)
                                    Text(
                                      formatCop(item.unitPrice),
                                      style: text.bodySmall?.copyWith(
                                        color: colors.onSurface.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Chip "Detalle" — el único control del
                            // desplegable (§021b): píldora outlined
                            // con el chevron dentro; Semantics anuncia
                            // el estado expandible a TalkBack y el
                            // InkWell llega a 40dp de hit area.
                            Semantics(
                              container: true,
                              button: true,
                              expanded: _expanded,
                              label: l10n.cartItemDetailToggle,
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _expanded = !_expanded),
                                customBorder: const StadiumBorder(),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 40,
                                  ),
                                  // Chip alineado a la altura del
                                  // título (top), no al centro del
                                  // hit area de 40dp.
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: colors.outlineVariant,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            l10n.cartItemDetail,
                                            style: text.labelSmall?.copyWith(
                                              color: colors.onSurface
                                                  .withValues(alpha: 0.75),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 1),
                                          Icon(
                                            _expanded
                                                ? Icons.expand_less_rounded
                                                : Icons.expand_more_rounded,
                                            size: 14,
                                            color: colors.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // AnimatedSize — la misma física del picker de
                        // reemplazo del detalle (180ms easeOutCubic).
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          clipBehavior: Clip.hardEdge,
                          child: _expanded
                              ? CartItemDetailPanel(item: item)
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            QuantityStepper(
                              quantity: item.quantity,
                              onChanged: widget.onQuantityChanged,
                            ),
                            // Eliminar visible: affordance del swipe
                            // y vía accesible sin gesto (revisor-ui).
                            SizedBox(
                              height: 44,
                              width: 44,
                              child: IconButton(
                                style: IconButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: widget.onRemove,
                                tooltip: l10n.cartRemoveTooltip,
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: colors.onSurface.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              formatCop(item.lineTotal),
                              style: text.titleSmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Recuadro flotante a caballo del borde de la card —
              // centrado vertical sin importar el alto del contenido.
              Positioned(
                left: cardLeft - kFrameOverhang,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IgnorePointer(
                    child: ProductImage(
                      asset: CatalogAssets.productAsset(item.productSlug),
                      imageUrl: item.imageUrl,
                      size: _imageSize,
                    ),
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
