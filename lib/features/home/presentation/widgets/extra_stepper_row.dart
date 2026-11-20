import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../cart/presentation/widgets/quantity_stepper.dart';
import '../utils/format_cop.dart';

/// Fila de adicional con contador de porciones (§045): nombre + precio
/// (total `extra × N` cuando hay selección, unitario cuando no) +
/// stepper reutilizado del carrito. `enabled=false` la deja gris —
/// opción agotada o quitada del perro.
class ExtraStepperRow extends StatelessWidget {
  const ExtraStepperRow({
    required this.label,
    required this.unitPrice,
    required this.times,
    required this.onChanged,
    required this.enabled,
    this.disabledLabel,
    super.key,
  });

  final String label;
  final int unitPrice;
  final int times;
  final ValueChanged<int> onChanged;
  final bool enabled;

  /// Texto del trailing cuando no está disponible (ej. "Agotado").
  final String? disabledLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final muted = enabled ? null : colors.onSurface.withValues(alpha: 0.38);
    final priceLabel =
        disabledLabel ??
        (unitPrice > 0
            ? '+${formatCop(times > 0 ? unitPrice * times : unitPrice)}'
            : l10n.orderSummaryFree);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            Expanded(
              // 2 líneas: el stepper deja ~180px al nombre — nombres
              // como "Salsa de queso cheddar" no caben en una (§045).
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: muted),
              ),
            ),
            Text(
              priceLabel,
              style: text.bodySmall?.copyWith(
                color: muted ?? colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            IgnorePointer(
              ignoring: !enabled,
              child: QuantityStepper(quantity: times, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}
