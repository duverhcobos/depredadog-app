import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_order.dart';
import '../cubit/admin_queue_cubit.dart';

/// La siguiente acción real del pedido en la matriz de 5 pasos
/// (§036): received→confirmed→preparing→ready→done + el cobro como
/// puerta en DOS puntos (decisión del dueño):
/// - `received` + recogida sin cobrar → "Registrar pago". La puerta
///   hoy solo dispara en PRESENCIAL (mostrador o pedido por
///   teléfono — el dueño certifica la plata a mano): la recogida
///   ONLINE solo acepta Nequi dentro de la app (§036 — efectivo/
///   transfer dejan producir para un cliente que nunca llega).
///   El resto del received sí confirma — mesa se sirve antes de
///   cobrar, delivery lo cobra el dueño en la puerta (contraentrega)
///   o verifica la transfer al final.
/// - `ready` + sin cobrar → "Registrar pago" (el done del backend exige
///   PAID — 409 PaymentNotSettled).
/// - `nequi` sin confirmar → SIN ACCIÓN (§036): el cobro dentro de
///   la app lo confirma el webhook del backend — ni Registrar pago
///   ni Confirmar se ofrecen hasta que reporte (pending = espera,
///   failed = rechazado, solo queda cancelar desde el detalle).
/// Terminal = sin acción.
enum AdminOrderAction { confirm, prepare, markReady, markPaid, markDone }

/// Resuelve la acción de la matriz para [order] — null en terminal
/// y en el pedido Nequi aún no confirmado por el webhook.
AdminOrderAction? adminOrderNextAction(AdminOrder order) {
  if (order.isTerminal || order.awaitsWebhook) return null;
  // Cualquier pago no saldado (pending o failed — un cobro
  // rechazado sigue debiendo) vuelve "Registrar pago" el paso real en
  // sus dos puertas: la recogida no se confirma sin plata y el
  // Entregado tampoco — devolver el paso habilitaría un toque
  // que el 409 rechaza (§035).
  final paymentGate =
      order.status == OrderStatus.ready ||
      (order.status == OrderStatus.received &&
          order.serviceType == AdminServiceType.pickup);
  if (paymentGate && order.paymentStatus != OrderPaymentStatus.paid) {
    return AdminOrderAction.markPaid;
  }
  return switch (order.status) {
    OrderStatus.received => AdminOrderAction.confirm,
    OrderStatus.confirmed => AdminOrderAction.prepare,
    OrderStatus.preparing => AdminOrderAction.markReady,
    OrderStatus.ready => AdminOrderAction.markDone,
    OrderStatus.done || OrderStatus.cancelled => null,
  };
}

/// Label del botón según la acción — `markReady` cambia por canal
/// (§022): delivery "Va en camino", dineIn "Servir", pickup "Listo
/// p/recoger".
String adminOrderActionLabel(
  AppLocalizations l10n,
  AdminOrderAction action, {
  AdminServiceType? serviceType,
}) => switch (action) {
  AdminOrderAction.confirm => l10n.adminActionConfirm,
  AdminOrderAction.prepare => l10n.adminActionPrepare,
  AdminOrderAction.markReady => switch (serviceType) {
    AdminServiceType.delivery => l10n.adminActionOnTheWay,
    AdminServiceType.dineIn => l10n.adminActionServe,
    _ => l10n.adminActionReadyPickup,
  },
  AdminOrderAction.markPaid => l10n.adminActionPaid,
  AdminOrderAction.markDone => l10n.adminActionDeliver,
};

/// Ejecuta [action] sobre el cubit compartido y, al resolver el
/// mock, levanta el toast de éxito correspondiente. La acción llega
/// explícita — el llamador decide: el botón primario usa la matriz
/// (`adminOrderNextAction`) pero el "Registrar pago" de la fila de pago del
/// detalle SIEMPRE cobra, aunque la matriz apunte a otro paso (un
/// received con pago pendiente puede cobrarse antes de confirmarse).
/// Sin confirmación para avanzar/cobrar (no destructivo — equivocarse
/// se corrige fácil, §035); solo "Cancelar" pide diálogo, y vive en
/// el detalle.
Future<void> runAdminOrderAction(
  BuildContext context,
  AdminOrder order,
  AdminOrderAction action,
) async {
  final cubit = context.read<AdminQueueCubit>();
  switch (action) {
    case AdminOrderAction.confirm:
      await cubit.advanceOrder(order.id);
    case AdminOrderAction.prepare:
      await cubit.advanceOrder(order.id);
    case AdminOrderAction.markReady:
      await cubit.advanceOrder(order.id);
    case AdminOrderAction.markPaid:
      await cubit.markPaid(order.id);
    case AdminOrderAction.markDone:
      await cubit.advanceOrder(order.id);
  }
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context)!;
  AppToast.success(context, switch (action) {
    AdminOrderAction.confirm => l10n.adminToastOrderConfirmed,
    AdminOrderAction.prepare => l10n.adminToastOrderPreparing,
    AdminOrderAction.markReady => l10n.adminToastOrderReady,
    AdminOrderAction.markPaid => l10n.adminToastPaymentConfirmed,
    AdminOrderAction.markDone => l10n.adminToastOrderDone,
  });
}

/// Rótulo del pedido Nequi sin confirmar (§036): ocupa el slot del
/// botón de acción pero NO es interactivo — explica por qué no hay
/// nada que tocar. pending → "Esperando confirmación de Nequi…"
/// (tono vivo, el webhook aún no habla); failed → "Nequi rechazó
/// el pago — cancela el pedido" (tono error, la única salida es
/// cancelar desde el detalle). Lo comparten la card y el footer.
class AdminOrderAwaitingHint extends StatelessWidget {
  const AdminOrderAwaitingHint({required this.order, super.key});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final failed = order.paymentStatus == OrderPaymentStatus.failed;
    final fg = failed ? colors.error : colors.onSurface.withValues(alpha: 0.6);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: (failed ? colors.error : colors.onSurface).withValues(
          alpha: failed ? 0.10 : 0.06,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            failed
                ? Icons.error_outline_rounded
                : Icons.hourglass_top_rounded,
            size: 15,
            color: fg,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              failed ? l10n.adminNequiFailedHint : l10n.adminAwaitingNequiHint,
              style: text.bodySmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// El botón de acción — FilledButton de ancho completo: el área de
/// toque más grande posible porque la acción ES el punto de la
/// pantalla (§035). Lo comparten la card de la cola (fila inferior)
/// y el footer del detalle. En [busy] el CTA sigue mostaza con el
/// spinner inline (convención checkout — elevated_button_primary):
/// IgnorePointer bloquea el toque y el cubit ignora re-entradas;
/// deshabilitar el botón apagaría el color y el spinner negro se
/// perdería (revisor-ui §035).
class AdminOrderActionButton extends StatelessWidget {
  const AdminOrderActionButton({
    required this.order,
    required this.busy,
    super.key,
  });

  final AdminOrder order;

  /// `state.busyOrderIds.contains(order.id)` — lo decide el padre,
  /// que ya observa el cubit.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final action = adminOrderNextAction(order);
    if (action == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return SizedBox(
      width: double.infinity,
      child: IgnorePointer(
        ignoring: busy,
        child: FilledButton(
          onPressed: () => runAdminOrderAction(context, order, action),
          child: busy
              ? SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: onPrimary,
                  ),
                )
              : Text(
                  adminOrderActionLabel(
                    l10n,
                    action,
                    serviceType: order.serviceType,
                  ),
                ),
        ),
      ),
    );
  }
}
