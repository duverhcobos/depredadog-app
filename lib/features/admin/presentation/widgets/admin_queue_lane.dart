import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../../orders/domain/entities/customer_order.dart';
import '../cubit/admin_queue_state.dart';
import 'admin_order_card.dart';

/// Una página-carril del kanban (§036): la lista vertical del estado
/// en FIFO. El carril vacío muestra un empty compacto — en kanban el
/// carril existe aunque no tenga pedidos (la ausencia también es
/// información: "nada en la plancha"). `RefreshIndicator` no va aquí
/// — el pull-to-refresh vive a nivel tablero (mismo gesto de
/// siempre); el vacío igual queda scrolleable para que el gesto
/// alcance también en carriles sin cards.
class AdminQueueLane extends StatelessWidget {
  const AdminQueueLane({required this.status, required this.state, super.key});

  final OrderStatus status;
  final AdminQueueState state;

  @override
  Widget build(BuildContext context) {
    final orders = state.laneOrders(status);
    if (orders.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      final colors = Theme.of(context).colorScheme;
      final text = Theme.of(context).textTheme;
      return LayoutBuilder(
        builder: (context, c) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // Zona negra — el texto no puede pintar sobre la franja
          // (misma regla §034c que el vacío/error global).
          padding: EdgeInsets.only(left: c.maxWidth * kSignatureStripFraction),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.adminLaneEmpty,
                    style: text.titleMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final order in orders)
          AdminOrderCard(
            order: order,
            busy: state.busyOrderIds.contains(order.id),
          ),
      ],
    );
  }
}
