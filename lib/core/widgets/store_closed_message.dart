import 'package:flutter/material.dart';

/// Mensaje que OCUPA EL LUGAR DEL CTA cuando el local está cerrado
/// (§029 — decisión usuario: no botón deshabilitado). Misma familia
/// de los avisos inline: ícono info + texto en error, ocupando el
/// ancho del botón que reemplaza. Altura fija 48 — idéntica al slot
/// del FilledButton para que el footer no salte al cambiar.
/// Semantics(liveRegion): el swap botón→mensaje se anuncia a lector.
class StoreClosedMessage extends StatelessWidget {
  const StoreClosedMessage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: colors.error),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
