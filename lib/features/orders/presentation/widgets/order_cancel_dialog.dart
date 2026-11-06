import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Diálogo de confirmación de cancelación (§023) — compartido por la
/// straddle card activa y el detalle (revisor-ui: el drill-down debe
/// ser al menos tan capaz como el resumen). Devuelve `true` si el
/// usuario confirma; la cancelación real es `OrdersCubit.cancelOrder`
/// (la ventana solo existe en "Recibido"/pending).
Future<bool> showOrderCancelDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.orderCancelTitle),
      content: Text(l10n.orderCancelBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.orderCancelKeep),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          child: Text(l10n.orderCancelConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
