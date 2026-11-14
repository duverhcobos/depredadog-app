import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_order.dart';

/// Chips del pedido admin (§034) — misma familia tonal de
/// order_status_chip del cliente (píldora radius pill, labelSmall
/// w700, tinte semántico a alpha bajo). Cuatro piezas de la misma
/// responsabilidad: servicio, canal, estado del pedido y estado
/// del pago.

/// Píldora de servicio — Domicilio (hay que salir) / Recogida
/// (vienen por él) / Mesa (se sirve ahí). Es el chip de la CARD
/// de la cola: el dato operativo que el dueño escanea (decisión
/// del dueño §036 — el canal online/presencial se mudó al
/// detalle). Tono secondaryContainer como el `tag` de
/// CustomizationSection: información operativa, no estado vivo.
class AdminServiceChip extends StatelessWidget {
  const AdminServiceChip({required this.serviceType, super.key});

  final AdminServiceType serviceType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (icon, label) = switch (serviceType) {
      AdminServiceType.delivery => (
        Icons.moped_rounded,
        l10n.adminServiceDelivery,
      ),
      AdminServiceType.pickup => (
        Icons.takeout_dining_rounded,
        l10n.adminServicePickup,
      ),
      AdminServiceType.dineIn => (
        Icons.table_restaurant_rounded,
        l10n.adminServiceDineIn,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
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

/// Etiqueta de canal "susurro" — Online 📱 / Presencial 🏪 sin
/// píldora. Vive en la esquina superior derecha de la CARD (§036,
/// decisión del dueño): el chip de servicio manda en la fila y el
/// canal se lee en apagado — contexto sin competir. El detalle
/// usa la versión píldora de abajo. La etiqueta cede en angosto:
/// el texto elipsiza (el ícono sobrevive) — por eso el Flexible
/// interno, que exige padre de ancho acotado (la card le da uno).
class AdminChannelTag extends StatelessWidget {
  const AdminChannelTag({required this.channel, super.key});

  final AdminOrderChannel channel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final online = channel == AdminOrderChannel.online;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          online ? Icons.smartphone_rounded : Icons.storefront_rounded,
          size: 12,
          color: muted,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            online ? l10n.adminChannelOnline : l10n.adminChannelInPerson,
            style: text.labelSmall?.copyWith(color: muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Píldora de canal — Online (la app) / Presencial (lo tomó el
/// dueño). Vive en el detalle (§036): la card usa la etiqueta
/// susurro de arriba — la píldora aquí conversa al nivel de los
/// chips de servicio/estado del encabezado del detalle.
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
/// tinte con el chip del cliente. §036 — el kanban agrega `ready`
/// ("Listo") y el `done` se lee "Entregado" siempre: es el carril
/// que espera el cierre, no el "listo para recoger" del cliente.
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
      OrderStatus.ready => (
        l10n.orderStatusReady,
        // La rampa de los vivos sube con el avance — ready es el
        // último paso antes del terminal: el tinte más fuerte.
        colors.primary.withValues(alpha: 0.32),
        colors.primary,
      ),
      OrderStatus.done => (
        l10n.orderStatusDelivered,
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
