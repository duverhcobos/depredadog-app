import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/checkout_state.dart';

/// Toggle segmentado propio del checkout (§022 — componente
/// `segmented_toggle` del design system): 2 píldoras radius pill dentro
/// de un track surfaceContainerHighest; la activa se rellena de primary
/// con texto onPrimary (misma decisión visual del SelectChip lleno).
class OrderTypeToggle extends StatelessWidget {
  const OrderTypeToggle({
    required this.orderType,
    required this.onChanged,
    super.key,
  });

  final CheckoutOrderType orderType;
  final ValueChanged<CheckoutOrderType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Container(
      // Track 48dp → píldoras de 40dp de hit area (mínimo de
      // controles interactivos, revisor-ui).
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _Pill(
            label: l10n.checkoutPickupOption,
            selected: orderType == CheckoutOrderType.pickup,
            onTap: () => onChanged(CheckoutOrderType.pickup),
          ),
          _Pill(
            label: l10n.checkoutDeliveryOption,
            selected: orderType == CheckoutOrderType.delivery,
            onTap: () => onChanged(CheckoutOrderType.delivery),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Expanded(
      // Estado de selección para TalkBack — comportamiento de radio
      // dentro del grupo (revisor-ui).
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(
                color: selected
                    ? colors.onPrimary
                    : colors.onSurface.withValues(alpha: 0.7),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
