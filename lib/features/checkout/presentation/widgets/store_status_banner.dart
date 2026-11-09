import 'package:flutter/material.dart';

/// Aviso fijo sobre el footer del checkout (§025): el local está
/// cerrado (isOpen=false — el CTA queda deshabilitado; el backend
/// rechaza con 409) o GET /store/config falló (texto + retry — el
/// placeholder cerrado también bloquea el CTA, cerrado por defecto =
/// seguro). Ícono + mensaje en error + botón opcional.
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
