import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../orders/domain/entities/customer_order.dart';
import '../../../domain/entities/admin_order.dart';
import '../admin_order_action.dart';

/// Bloque de acciones del detalle admin (§035/§036) — contenido del
/// FOOTER FIJO opaco que la pantalla monta bajo el ListView
/// (decisión del usuario: la familia Column[ListView + footer] de
/// cart/checkout, no suelto sobre la franja):
///
/// - Primario de avance — la misma matriz de 5 pasos de la card
///   (Confirmar / Preparar / label-por-canal / Registrar pago / Entregado,
///   un toque sin confirmación).
/// - El paso bloqueado DESHABILITADO con pista cuando la acción
///   real es cobrar (§036): "Entregado" en ready+sin-pago,
///   "Confirmar" en recogida+sin-pago — adelanta la regla del
///   backend (409 PaymentNotSettled) en vez de dejar que falle.
/// - "Cancelar pedido" (text-button color error) → diálogo con
///   motivo opcional — lo destructivo solo vive acá (la card nunca
///   destruye).
///
/// En terminal la pantalla ni siquiera monta el footer — el detalle
/// queda abierto en solo lectura.
class AdminOrderDetailActions extends StatelessWidget {
  const AdminOrderDetailActions({
    required this.order,
    required this.busy,
    required this.onCancel,
    super.key,
  });

  final AdminOrder order;
  final bool busy;

  /// Abre el diálogo de cancelación (motivo opcional) y corre el
  /// cancel + toast + pop — la pantalla lo orquesta porque el pop
  /// es navegación suya.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (order.isTerminal) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final action = adminOrderNextAction(order);
    // Nequi sin confirmar por el webhook (§036): ningún botón hasta
    // que reporte — ni avance ni cobro manual ni cancelar (decisión
    // del dueño: la espera es literal). Si el webhook ya dijo FAILED
    // el pedido está muerto — la única salida es cancelarlo.
    if (order.awaitsWebhook) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminOrderAwaitingHint(order: order),
          if (order.paymentStatus == OrderPaymentStatus.failed) ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: busy ? null : onCancel,
                style: TextButton.styleFrom(foregroundColor: colors.error),
                child: Text(l10n.orderCancelCta),
              ),
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminOrderActionButton(order: order, busy: busy),
        // El pago manda: el paso que bloquea se muestra
        // deshabilitado con su pista en vez de esconder la regla —
        // "Confirmar" si la puerta es la recogida sin cobrar,
        // "Entregado" si es el ready sin cobrar (§036).
        if (action == AdminOrderAction.markPaid) ...[
          const SizedBox(height: 8),
          FilledButton(
            onPressed: null,
            child: Text(
              adminOrderActionLabel(
                l10n,
                order.status == OrderStatus.received
                    ? AdminOrderAction.confirm
                    : AdminOrderAction.markDone,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 13,
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.adminDoneNeedsPayment,
                style: text.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: busy ? null : onCancel,
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: Text(l10n.orderCancelCta),
          ),
        ),
      ],
    );
  }
}
