import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../cubit/admin_queue_state.dart';

/// Filtro segmentado de la cola admin (§034) — componente
/// `segmented_toggle` del design system (mismo idioma del
/// OrderTypeToggle del checkout): track surfaceContainerHighest
/// radius pill con 2 píldoras Expanded; la activa se rellena de
/// primary con texto onPrimary. Acotado a la zona negra como las
/// cards (nace dentro de la franja).
class AdminQueueSegmentedFilter extends StatelessWidget {
  const AdminQueueSegmentedFilter({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final AdminQueueFilter selected;
  final ValueChanged<AdminQueueFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, c) => Padding(
          padding: EdgeInsets.only(
            left: c.maxWidth * kSignatureStripFraction * kCardStripInset,
            right: blackZoneMargin(c.maxWidth),
          ),
          child: Container(
            // Track 56dp → píldoras de 48dp de hit area real — el
            // mínimo interactivo (revisor-ui §034: el track de 48
            // heredado del toggle del checkout dejaba 40dp).
            height: 56,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
            ),
            // Thumb deslizante (feedback del usuario §034c: el fill
            // estático se leía "sin animación") — la píldora mostaza
            // VIAJA entre segmentos como el segmented control de
            // referencia; los labels quedan encima transparentes.
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: selected == AdminQueueFilter.active
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _Pill(
                      label: l10n.adminQueueFilterActive,
                      selected: selected == AdminQueueFilter.active,
                      onTap: () => onChanged(AdminQueueFilter.active),
                    ),
                    _Pill(
                      label: l10n.adminQueueFilterHistory,
                      selected: selected == AdminQueueFilter.history,
                      onTap: () => onChanged(AdminQueueFilter.history),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
      // Estado de selección para TalkBack — radio dentro del grupo.
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: text.bodyMedium!.copyWith(
                color: selected
                    ? colors.onPrimary
                    : colors.onSurface.withValues(alpha: 0.7),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }
}
