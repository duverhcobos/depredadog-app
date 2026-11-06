import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Stepper − n + de la fila del carrito (§020). Botones 44dp —
/// target de toque real (revisor-ui §020: el pill se ve compacto
/// pero la acción central del carrito no puede pedir puntería).
/// El caller decide qué pasa al llegar a 0 (cart elimina la fila).
/// Semántica: tooltips localizados en −/+ y la cantidad se anuncia
/// como "Cantidad: N".
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.quantity,
    required this.onChanged,
    super.key,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget button(IconData icon, int delta, String tooltip) => SizedBox(
      height: 44,
      width: 44,
      child: IconButton(
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => onChanged(quantity + delta),
        tooltip: tooltip,
        icon: Icon(icon, size: 20, color: colors.primary),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, -1, l10n.cartStepperRemove),
          Semantics(
            label: l10n.cartStepperQty(quantity),
            // Sin excludeSemantics el Text suelto anunciaba "2"
            // además del label → TalkBack repetía la cantidad.
            excludeSemantics: true,
            child: SizedBox(
              width: 28,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          button(Icons.add_rounded, 1, l10n.cartStepperAdd),
        ],
      ),
    );
  }
}
