import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Bottom sheet "¿A cuántos aplicar?" (§021) — solo se muestra al
/// guardar la edición de una fila con quantity > 1 (decisión del
/// usuario: pregunta al guardar). Devuelve true = a todas, false =
/// solo 1 unidad, null = cancelado.
Future<bool?> showCartEditScopeSheet(
  BuildContext context, {
  required int quantity,
}) {
  final l10n = AppLocalizations.of(context)!;
  final colors = Theme.of(context).colorScheme;
  final text = Theme.of(context).textTheme;
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: colors.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.cartEditScopeTitle,
              style: text.titleSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.looks_one_rounded),
            title: Text(l10n.cartEditScopeOne),
            onTap: () => Navigator.of(context).pop(false),
          ),
          ListTile(
            leading: const Icon(Icons.format_list_numbered_rounded),
            title: Text(l10n.cartEditScopeAll(quantity)),
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
