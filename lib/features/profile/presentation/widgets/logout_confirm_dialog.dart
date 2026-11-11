import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Diálogo de confirmación de "Cerrar sesión" (§030) — mismo patrón
/// de `showOrderCancelDialog`: cancelar / confirmar rojo. Devuelve
/// `true` si el usuario confirma; la acción real (fase 1: stub del
/// ProfileCubit — fase 2: POST /auth/logout best-effort + limpieza
/// local + go /login) la gatilla el caller.
Future<bool> showLogoutConfirmDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.profileLogoutConfirmTitle),
      content: Text(l10n.profileLogoutConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.profileCancelAction),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          child: Text(l10n.profileLogoutConfirmAction),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
