import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../home/presentation/widgets/customization_section.dart';
import '../../../../orders/domain/entities/customer_order.dart';
import '../../../domain/entities/admin_order.dart';
import '../admin_elapsed_text.dart';
import '../admin_order_chips.dart';

/// Header del detalle admin (§035) — sección "Pedido": chips de
/// canal + estado del pedido, fila cliente (nombre o "En el local ·
/// Mesa N" / "En el local") con la frescura viva, y el #id corto en
/// el tag de la sección (cola del id — los ids reales del backend
/// son largos; el dueño solo necesita distinguirlo).
class AdminOrderDetailHeader extends StatelessWidget {
  const AdminOrderDetailHeader({required this.order, super.key});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    final name = order.customerName;
    final table = order.tableLabel;
    final label =
        name ??
        (table != null
            ? l10n.adminOrderAtTable(table)
            : l10n.adminOrderInHouse);
    return CustomizationSection(
      title: l10n.adminOrderDetailOrderSection,
      tag: l10n.adminOrderShortId(order.shortTag),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Canal + servicio — el detalle muestra los dos
                  // (la card solo el de servicio, decisión §036).
                  AdminChannelChip(channel: order.channel),
                  const SizedBox(width: 6),
                  AdminServiceChip(serviceType: order.serviceType),
                  const Spacer(),
                  AdminOrderStatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    name != null
                        ? Icons.person_outline_rounded
                        : Icons.table_restaurant_outlined,
                    size: 15,
                    color: muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AdminElapsedText(
                    placedAt: order.placedAt,
                    style: text.labelSmall?.copyWith(color: muted),
                  ),
                ],
              ),
              // El motivo queda con el pedido cancelado — el dueño lo
              // escribió al cancelar y el historial lo conserva.
              if (order.status == OrderStatus.cancelled &&
                  order.cancelReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  order.cancelReason!,
                  style: text.bodySmall?.copyWith(
                    color: colors.error.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
