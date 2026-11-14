import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/customer_order.dart';

/// Píldora de estado del pedido (§023): label + tinte semántico.
/// En curso = primary (la atención viva); done = tertiary (verde
/// pepinillo del sistema — token, no hex); cancelled = error.
/// `muted` (historial): mismo tinte a α0.55 — los terminales son
/// evidencia, no acción (semántica honesta del drill-down).
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({required this.order, this.muted = false, super.key});

  final CustomerOrder order;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    // muted atenúa en DOS niveles: el fondo baja fuerte (el chip
    // deja de competir) pero el texto baja suave — a 0.55 un
    // labelSmall de 11px quedaba ~3:1, bajo el 4.5:1 de WCAG AA
    // para texto-información (revisor-ui §023).
    final bgFade = muted ? 0.55 : 1.0;
    final fgFade = muted ? 0.8 : 1.0;
    final (label, bg, fg) = switch (order.status) {
      OrderStatus.received || OrderStatus.confirmed => (
        order.status == OrderStatus.received
            ? l10n.orderStatusReceived
            : l10n.orderStatusConfirmed,
        colors.primary.withValues(alpha: 0.14 * bgFade),
        colors.primary.withValues(alpha: fgFade),
      ),
      OrderStatus.preparing => (
        l10n.orderStatusPreparing,
        colors.primary.withValues(alpha: 0.22 * bgFade),
        colors.primary.withValues(alpha: fgFade),
      ),
      // ready (§036): la cocina ya terminó — pickup "Listo",
      // delivery "Va en camino"; misma evidencia tertiary del done.
      OrderStatus.ready => (
        order.serviceType == OrderServiceType.pickup
            ? l10n.orderStatusReady
            : l10n.adminActionOnTheWay,
        colors.tertiary.withValues(alpha: 0.18 * bgFade),
        colors.tertiary.withValues(alpha: fgFade),
      ),
      OrderStatus.done => (
        order.serviceType == OrderServiceType.pickup
            ? l10n.orderStatusReady
            : l10n.orderStatusDelivered,
        colors.tertiary.withValues(alpha: 0.18 * bgFade),
        colors.tertiary.withValues(alpha: fgFade),
      ),
      OrderStatus.cancelled => (
        l10n.orderStatusCancelled,
        colors.error.withValues(alpha: 0.14 * bgFade),
        colors.error.withValues(alpha: fgFade),
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
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}
