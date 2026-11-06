import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../domain/entities/customer_order.dart';
import '../utils/format_order_date.dart';
import 'order_status_chip.dart';

/// Fila-pill del historial (§023 — idioma "filas-pill" del
/// summary-drilldown): servicio + fecha + N ítems + total + chip de
/// estado atenuado (terminal = evidencia) + chevron → detalle.
class OrderHistoryTile extends StatelessWidget {
  const OrderHistoryTile({required this.order, super.key});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDelivery = order.serviceType == OrderServiceType.delivery;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () =>
            context.push('${AuthGuard.ordersRoute}/${order.id}', extra: order),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                isDelivery ? Icons.moped_rounded : Icons.storefront_rounded,
                size: 18,
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatOrderDate(order.placedAt),
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      l10n.orderItemsCount(order.itemCount),
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCop(order.total),
                    style: text.bodyMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  OrderStatusChip(order: order, muted: true),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                // Único indicio de "hay detalle" — 0.4 era casi
                // imperceptible sobre negro (revisor-ui §023).
                color: colors.onSurface.withValues(alpha: 0.65),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
