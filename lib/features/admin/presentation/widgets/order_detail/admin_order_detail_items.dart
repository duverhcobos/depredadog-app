import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../home/presentation/utils/format_cop.dart';
import '../../../../home/presentation/widgets/customization_section.dart';
import '../../../../orders/domain/entities/customer_order.dart';
import '../../../../orders/presentation/widgets/order_item_detail_panel.dart';
import '../../../domain/entities/admin_order.dart';

/// Ítems COMPLETOS del pedido admin (§035/§037) — la lista entera,
/// una fila por ítem (cantidad × nombre + lineTotal) con el chip
/// "Detalle" que despliega el armado de cada perro
/// (OrderItemDetailPanel — el MISMO panel del detalle del cliente
/// §023): "sin cebolla" es instrucción de cocina, el ítem con
/// modificadores nace DESPLEGADO y el que solo trae snapshot de
/// incluidos espera el toque. Cierra con el desglose del cobro:
/// subtotal + domicilio (solo delivery) + total.
class AdminOrderDetailItems extends StatelessWidget {
  const AdminOrderDetailItems({required this.order, super.key});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return CustomizationSection(
      title: l10n.adminOrderDetailItemsSection,
      children: [
        for (final item in order.items) _ItemLine(item: item),
        Divider(
          height: 24,
          indent: 14,
          endIndent: 14,
          color: colors.outlineVariant.withValues(alpha: 0.4),
        ),
        _Totals(order: order),
      ],
    );
  }
}

/// "2× El Depredador — $50.000" + chip "Detalle" expandible — mismo
/// patrón `_ItemLine` del detalle del cliente (§023), con la regla de
/// cocina del §037: el chip solo existe cuando el ítem tiene algo que
/// ver (modificadores o incluidos — un perro estándar no gasta un chip
/// que abre a "Así como viene") y nace DESPLEGADO cuando trae
/// modificadores (la instrucción no puede depender de que el dueño
/// toque). unitPrice apagado solo cuando qty>1.
class _ItemLine extends StatefulWidget {
  const _ItemLine({required this.item});

  final OrderItem item;

  @override
  State<_ItemLine> createState() => _ItemLineState();
}

class _ItemLineState extends State<_ItemLine> {
  /// Auto-expandido de nacimiento con modificadores (§037 — "sin
  /// cebolla" es instrucción de cocina); colapsado cuando solo hay
  /// snapshot de incluidos — el chip lo abre.
  late bool _expanded = widget.item.modifiers.isNotEmpty;

  @override
  void didUpdateWidget(covariant _ItemLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    // §039: los modifiers llegan DESPUÉS (GET /admin/orders/:id — el
    // listado los manda vacíos pero sí trae includedNames, así que el
    // ítem custom nace colapsado). Un ítem que los gana al hidratarse
    // se auto-expande — la instrucción de cocina no pide un toque.
    if (widget.item.modifiers.isNotEmpty &&
        oldWidget.item.modifiers.isEmpty) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final item = widget.item;
    final hasDetail =
        item.modifiers.isNotEmpty || item.includedNames.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                      '${item.quantity}× ${item.name}',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    // Solo con qty>1: con 1 duplicaba el lineTotal
                    // (revisor-ui §020 — misma regla del cart tile).
                    if (item.quantity > 1)
                      Text(
                        formatCop(item.unitPrice),
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Chip "Detalle" — solo cuando hay algo que ver (§037);
              // píldora outlined con el chevron dentro, idéntica a la
              // del detalle del cliente.
              if (hasDetail) ...[
                Semantics(
                  container: true,
                  button: true,
                  expanded: _expanded,
                  label: l10n.cartItemDetailToggle,
                  child: InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    customBorder: const StadiumBorder(),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.cartItemDetail,
                                style: text.labelSmall?.copyWith(
                                  color: colors.onSurface.withValues(
                                    alpha: 0.75,
                                  ),
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
                const SizedBox(width: 8),
              ],
              Text(
                formatCop(item.lineTotal),
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          // AnimatedSize — la misma física del panel del carrito.
          if (hasDetail)
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: _expanded
                  ? OrderItemDetailPanel(item: item)
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

/// Desglose del cobro (§037) — subtotal / domicilio / total, mismo
/// idioma del `_Totals` del detalle del cliente: la fila Domicilio
/// solo aparece en delivery ("Gratis" en primary cuando fee==0) y el
/// Total canta en primary — apagado en cancelado (misma regla que la
/// card §035: no proclama plata que no entró).
class _Totals extends StatelessWidget {
  const _Totals({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cancelled = order.status == OrderStatus.cancelled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        children: [
          // Subtotal solo cuando el desglose separa algo — sin fila
          // Domicilio (pickup/mesa) Subtotal==Total duplica la misma
          // cifra (regla "no duplicar números" §020, revisor-ui §037 —
          // misma deduplicación que el _Totals del cliente).
          if (order.serviceType == AdminServiceType.delivery)
            _row(
              text,
              colors,
              l10n.orderSummarySubtotal,
              formatCop(order.subtotal),
            ),
          if (order.serviceType == AdminServiceType.delivery)
            _row(
              text,
              colors,
              l10n.orderSummaryDelivery,
              order.deliveryFee == 0
                  ? l10n.orderSummaryFree
                  : formatCop(order.deliveryFee),
              valuePrimary: order.deliveryFee == 0,
            ),
          const SizedBox(height: 4),
          _row(
            text,
            colors,
            l10n.orderSummaryTotal,
            formatCop(order.total),
            total: true,
            cancelled: cancelled,
          ),
        ],
      ),
    );
  }

  Widget _row(
    TextTheme text,
    ColorScheme colors,
    String label,
    String value, {
    bool valuePrimary = false,
    bool total = false,
    bool cancelled = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: (total ? text.titleSmall : text.bodySmall)?.copyWith(
              color: total
                  ? colors.onSurface
                  : colors.onSurface.withValues(alpha: 0.7),
              fontWeight: total ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: (total ? text.titleSmall : text.bodySmall)?.copyWith(
            // El cancelado no proclama plata que no entró (regla de
            // la card §035 — se conserva en la fila Total).
            color: cancelled && total
                ? colors.onSurface.withValues(alpha: 0.5)
                : valuePrimary || total
                ? colors.primary
                : colors.onSurface,
            fontWeight: cancelled && total
                ? FontWeight.w600
                : total || valuePrimary
                ? FontWeight.w800
                : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
