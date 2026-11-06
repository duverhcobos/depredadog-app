import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/customer_order.dart';

/// Progreso del pedido activo (§023): fila de 4 dots unidos por
/// línea — pasados y actual rellenos primary (pasados con check),
/// futuros outline. Gráfica pura de progreso — SIN caption visible:
/// el OrderStatusChip que la acompaña ya nombra el estado (revisor-
/// estetico §023 — el mismo texto a ~60dp leía como dato pegado);
/// el Semantics lo sigue anunciando a TalkBack.
///
/// `cancelled` no entra al stepper — la card/detalle lo muestran en
/// el chip con la razón debajo.
class OrderStatusStepper extends StatelessWidget {
  const OrderStatusStepper({required this.order, super.key});

  final CustomerOrder order;

  /// Índice del paso actual (0-3); done = último completo.
  int get _step => switch (order.status) {
    OrderStatus.received => 0,
    OrderStatus.confirmed => 1,
    OrderStatus.preparing => 2,
    OrderStatus.done || OrderStatus.cancelled => 3,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final label = switch (order.status) {
      OrderStatus.received => l10n.orderStepReceived,
      OrderStatus.confirmed => l10n.orderStepConfirmed,
      OrderStatus.preparing => l10n.orderStepPreparing,
      OrderStatus.done =>
        order.serviceType == OrderServiceType.pickup
            ? l10n.orderStepReady
            : l10n.orderStepDelivered,
      OrderStatus.cancelled => l10n.orderStatusCancelled,
    };
    return Semantics(
      // "Paso 3 de 4: En la plancha" — comunica el PROGRESO, no solo
      // el estado (revisor-ui §023); en cancelled (no entra al
      // stepper) queda la etiqueta plana.
      label: order.status == OrderStatus.cancelled
          ? label
          : l10n.orderStepProgress(_step + 1, 4, label),
      // container: la región propia conserva su etiqueta (sin ella se
      // funde en el semantics del ancestro y TalkBack la diluye).
      container: true,
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= _step ? colors.primary : colors.outlineVariant,
                ),
              ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= _step ? colors.primary : Colors.transparent,
                border: i <= _step
                    ? null
                    : Border.all(color: colors.outlineVariant, width: 2),
              ),
              child: i < _step
                  ? Icon(Icons.check_rounded, size: 12, color: colors.onPrimary)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
