import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Chip compacto de estado del local para el header del shell
/// (§029 — `StoreStatusCubit` lo alimenta con GET /store/config real;
/// con estado unknown el header no lo renderiza). Píldora dot +
/// "Abierto"/"Cerrado" junto a las notificaciones — el ETA vive en
/// el contexto donde aplica.
class StoreStatusChip extends StatelessWidget {
  const StoreStatusChip({required this.isOpen, super.key});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOpen ? colors.tertiary : colors.error,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOpen ? l10n.homeStoreOpen : l10n.homeStoreClosed,
            style: text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
