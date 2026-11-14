import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../home/presentation/widgets/customization_section.dart';
import '../../../../orders/domain/entities/customer_order.dart';
import '../../../domain/entities/admin_order.dart';
import '../admin_order_action.dart';
import '../admin_order_chips.dart';

/// Sección de pago del detalle admin (§035): método + chip del
/// estado del pago + botón "Registrar pago" visible solo cuando hay algo
/// que cobrar (pending/failed — el cash en la entrega o la
/// transferencia que llegó por fuera). En un cancelado la sección
/// entera se suprime: no hubo transacción y una card-título con
/// una sola etiqueta se lee incompleta (revisor-ui §035).
class AdminOrderDetailPayment extends StatelessWidget {
  const AdminOrderDetailPayment({
    required this.order,
    required this.busy,
    super.key,
  });

  final AdminOrder order;

  /// Operación mock en vuelo sobre este pedido — bloquea el segundo
  /// "Registrar pago" y muestra el spinner del claim.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final isCancelled = order.status == OrderStatus.cancelled;
    if (isCancelled) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    final (methodIcon, methodLabel) = switch (order.paymentMethod) {
      AdminPaymentMethod.cash => (
        Icons.payments_rounded,
        l10n.adminPaymentCash,
      ),
      AdminPaymentMethod.transfer => (
        Icons.sync_alt_rounded,
        l10n.adminPaymentTransfer,
      ),
      AdminPaymentMethod.nequi => (
        Icons.account_balance_wallet_rounded,
        l10n.adminPaymentNequi,
      ),
    };
    // "Registrar pago" tonal solo cuando la matriz NO lo pone ya como
    // primario — confirmed+pendiente muestra el mismo label y acción
    // dos veces en el mismo viewport (eco de composición,
    // revisor-estetico §035); received+pendiente sí lo conserva:
    // cobrar antes de confirmar es una acción DISTINTA al primario.
    // != paid cubre también failed: un pago rechazado sigue debiendo.
    // Nequi NUNCA tiene cobro manual (§036): solo el webhook
    // confirma — la fila se queda en método + estado.
    final canMarkPaid =
        !order.isTerminal &&
        order.paymentMethod != AdminPaymentMethod.nequi &&
        order.paymentStatus != OrderPaymentStatus.paid &&
        adminOrderNextAction(order) != AdminOrderAction.markPaid;
    return CustomizationSection(
      title: l10n.adminOrderDetailPaymentSection,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(methodIcon, size: 16, color: muted),
                  const SizedBox(width: 8),
                  Text(
                    methodLabel,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  AdminPaymentStatusChip(status: order.paymentStatus),
                ],
              ),
              if (canMarkPaid) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  // Misma convención del primario: el botón no se
                  // apaga en busy — IgnorePointer + guarda del cubit.
                  child: IgnorePointer(
                    ignoring: busy,
                    child: FilledButton.tonalIcon(
                      onPressed: () => runAdminOrderAction(
                        context,
                        order,
                        AdminOrderAction.markPaid,
                      ),
                      icon: busy
                          ? SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primary,
                              ),
                            )
                          : const Icon(Icons.payments_outlined, size: 18),
                      label: Text(l10n.adminActionPaid),
                    ),
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
