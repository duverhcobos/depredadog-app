import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';

/// WhatsApp del local — PLACEHOLDER de presentación (§030). La
/// integración lo toma de store_settings.support_phone cuando exista
/// (pendiente declarado); mientras tanto el diálogo lo muestra igual.
const String kSupportPhone = '+57 300 000 0000';

/// Diálogo de soporte (§030): el WhatsApp del local + botón copiar
/// número (mismo patrón Clipboard + toast del código de referido).
void showProfileSupportDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final colors = Theme.of(context).colorScheme;
  final text = Theme.of(context).textTheme;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.supportDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.supportDialogBody),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  kSupportPhone,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.profileCopyNumber,
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: kSupportPhone),
                  );
                  if (!dialogContext.mounted) return;
                  AppToast.success(
                    dialogContext,
                    l10n.profileCopiedNumberToast,
                  );
                },
                icon: Icon(Icons.copy_rounded, size: 20, color: colors.primary),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.supportDialogClose),
        ),
      ],
    ),
  );
}
