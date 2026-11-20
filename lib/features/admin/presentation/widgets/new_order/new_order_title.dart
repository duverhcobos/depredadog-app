import 'package:flutter/material.dart';

/// Título naciente de la comanda (§042) — mismo patrón
/// scrolling_title del cierre §036: primer hijo del scroll en la
/// zona negra (0.602 a la derecha) en mostaza pesada. Comparte la
/// pieza entre "Nueva orden" (comanda) y "Revisar y cobrar" (cobro).
class NewOrderTitle extends StatelessWidget {
  const NewOrderTitle({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.602,
        alignment: Alignment.centerRight,
        child: Padding(
          // Respiro bajo el título (decisión del dueño §042): sin
          // bottom el header medía ~44px y la banda de chips subía
          // pegada al área de toque de la flecha (12..60). 12+~34+16
          // ≈ 62px — el mismo ritmo del header de Cocina (~56-64).
          padding: const EdgeInsets.fromLTRB(0, 12, 16, 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              this.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.headlineSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
