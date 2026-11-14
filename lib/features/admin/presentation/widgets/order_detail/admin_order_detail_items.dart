import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../home/presentation/utils/format_cop.dart';
import '../../../../home/presentation/widgets/customization_section.dart';
import '../../../../orders/domain/entities/customer_order.dart';
import '../../../domain/entities/admin_order.dart';

/// Ítems COMPLETOS del pedido admin (§035) — la lista entera, una
/// fila por ítem (cantidad × nombre + lineTotal); la cola trunca a 2
/// líneas con "+N más" y acá el dueño ve los 7 ítems de una Mesa 5
/// sin abrir nada más. Cierra con el total cobrado (el DTO ya lo
/// trae compuesto: subtotal + deliveryFee).
class AdminOrderDetailItems extends StatelessWidget {
  const AdminOrderDetailItems({required this.order, super.key});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return CustomizationSection(
      title: l10n.adminOrderDetailItemsSection,
      children: [
        for (final item in order.items) _ItemRow(item: item),
        Divider(
          height: 24,
          indent: 14,
          endIndent: 14,
          color: colors.outlineVariant.withValues(alpha: 0.4),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.orderSummaryTotal,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                formatCop(order.total),
                // Misma regla que la card — el cancelado no proclama
                // plata que no entró (revisor-estetico §035).
                style: text.titleSmall?.copyWith(
                  color: order.status == OrderStatus.cancelled
                      ? colors.onSurface.withValues(alpha: 0.5)
                      : colors.primary,
                  fontWeight: order.status == OrderStatus.cancelled
                      ? FontWeight.w600
                      : FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "2× El Depredador — $50.000": nombre + qty fuerte, unitPrice
/// apagado solo cuando qty>1 (duplicaba el lineTotal — misma regla
/// del detalle del cliente §023 y del cart tile §020).
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.quantity}× ${item.name}',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
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
          Text(
            formatCop(item.lineTotal),
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
