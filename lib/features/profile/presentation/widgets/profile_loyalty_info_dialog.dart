import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Diálogo "¿Cómo funciona la manada?" (§030.1): explica puntos y
/// código de referidos con reglas GENÉRICAS de fase mock — las reglas
/// concretas (cuántos puntos por compra, premio por referido) se
/// definen con el módulo loyalty del backend. Mismo patrón AlertDialog
/// del diálogo de Soporte (§030).
void showProfileLoyaltyInfoDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.profileLoyaltyInfoTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.profileLoyaltyInfoPoints),
          const SizedBox(height: 12),
          Text(l10n.profileLoyaltyInfoCode),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.profileLoyaltyInfoClose),
        ),
      ],
    ),
  );
}
