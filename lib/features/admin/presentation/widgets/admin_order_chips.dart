import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_order.dart';

/// Chips del pedido admin (§034) — misma familia tonal de
/// order_status_chip del cliente (píldora radius pill, labelSmall
/// w700, tinte semántico a alpha bajo). Tres piezas de la misma
/// responsabilidad: canal, estado del pedido y estado del pago.

/// Píldora de canal — Online (la app) / Presencial (lo tomó el
/// dueño). Tono secondaryContainer como el `tag` de
/// CustomizationSection: información operativa, no estado vivo.
class AdminChannelChip extends StatelessWidget {
  const AdminChannelChip({required this.channel, super.key});

  final AdminOrderChannel channel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final online = channel == AdminOrderChannel.online;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            online ? Icons.smartphone_rounded : Icons.storefront_rounded,
            size: 12,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            online ? l10n.adminChannelOnline : l10n.adminChannelInPerson,
            style: text.labelSmall?.copyWith(
              color: colors.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Píldora de estado del pedido en la cola: pending se lee
/// "Pendiente" (el dueño lo opera como por-confirmar, no como el
/// "Recibido" del cliente); los demás estados comparten clave y
/// tinte con el chip del cliente (done → "Listo" siempre: la vista
/// del dueño no distingue pickup/delivery).
class AdminOrderStatusChip extends StatelessWidget {
  const AdminOrderStatusChip({required this.status, super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (label, bg, fg) = switch (status) {
      // Semáforo operativo (decisión del usuario §034): el que grita es
      // PENDIENTE — es el pedido que necesita la acción del dueño
      // (confirmarlo). Sólido primary/onPrimary; los demás vivos bajan
      // a tenue para que la cola se escanee de un vistazo.
      OrderStatus.received => (
        l10n.adminStatusPending,
        colors.primary,
        colors.onPrimary,
      ),
      OrderStatus.confirmed => (
        l10n.orderStatusConfirmed,
        colors.primary.withValues(alpha: 0.10),
        colors.primary,
      ),
      OrderStatus.preparing => (
        l10n.orderStatusPreparing,
        colors.primary.withValues(alpha: 0.22),
        colors.primary,
      ),
      OrderStatus.done => (
        l10n.orderStatusReady,
        colors.tertiary.withValues(alpha: 0.18),
        colors.tertiary,
      ),
      OrderStatus.cancelled => (
        l10n.orderStatusCancelled,
        colors.error.withValues(alpha: 0.14),
        colors.error,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: text.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Píldora del estado de PAGO (§034 — en la cola importa tanto como
/// el estado del pedido: el dueño confirma "me pagó"). paid =
/// tertiary (evidencia cerrada); pending = primary tenue (acción
/// viva — cobrar); failed = error.
class AdminPaymentStatusChip extends StatelessWidget {
  const AdminPaymentStatusChip({required this.status, super.key});

  final OrderPaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (label, bg, fg) = switch (status) {
      OrderPaymentStatus.paid => (
        l10n.adminPaymentPaid,
        colors.tertiary.withValues(alpha: 0.18),
        colors.tertiary,
      ),
      OrderPaymentStatus.pending => (
        l10n.adminPaymentPending,
        colors.primary.withValues(alpha: 0.14),
        colors.primary,
      ),
      OrderPaymentStatus.failed => (
        l10n.adminPaymentFailed,
        colors.error.withValues(alpha: 0.14),
        colors.error,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: text.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
