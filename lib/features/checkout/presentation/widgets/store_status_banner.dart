import 'package:flutter/material.dart';

/// Aviso fijo sobre el footer del checkout (§025): GET /store/config
/// falló (texto + retry — el placeholder cerrado también bloquea el
/// CTA, cerrado por defecto = seguro). El caso "local cerrado" ya no
/// usa banner: desde §029 el mensaje ocupa el slot del CTA mismo.
/// Ícono + mensaje en error + botón opcional.
class StoreStatusBanner extends StatelessWidget {
  const StoreStatusBanner({
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 0, 8),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: colors.error),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
