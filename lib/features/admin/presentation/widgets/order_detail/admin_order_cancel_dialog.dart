import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';

/// Diálogo de confirmación de cancelación del detalle admin (§035) —
/// lo destructivo solo vive en el detalle: el botón de la card nunca
/// cancela. Campo opcional de motivo (cancelReason ya lo acepta el
/// PATCH del backend §019).
///
/// Devuelve `null` si el dueño se arrepintió ("No, dejarlo" o tap
/// fuera) o el texto del motivo — posiblemente vacío, cancelar sin
/// razón también es válido (el cubit lo normaliza a null).
Future<String?> showAdminOrderCancelDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (dialogContext) => const _AdminOrderCancelDialog(),
    );

/// El diálogo con estado — el TextEditingController vive y muere
/// con su State (disponerlo desde el caller tras el await del
/// showDialog lo cerraba mientras la animación de salida aún lo
/// montaba).
class _AdminOrderCancelDialog extends StatefulWidget {
  const _AdminOrderCancelDialog();

  @override
  State<_AdminOrderCancelDialog> createState() =>
      _AdminOrderCancelDialogState();
}

class _AdminOrderCancelDialogState extends State<_AdminOrderCancelDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l10n.orderCancelTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.adminOrderCancelBody),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            // Sin autofocus — el motivo es opcional y el teclado
            // nacía tapando la confirmación destructiva a medias
            // (revisor-estetico §035): primero se lee y se decide.
            autofocus: false,
            maxLines: 2,
            minLines: 1,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(context).pop(value),
            decoration: InputDecoration(
              labelText: l10n.adminOrderCancelReasonLabel,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.orderCancelKeep),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_reason.text),
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          child: Text(l10n.orderCancelConfirm),
        ),
      ],
    );
  }
}
