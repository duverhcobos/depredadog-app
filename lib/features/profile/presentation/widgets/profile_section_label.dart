import 'package:flutter/material.dart';

import '../../../home/presentation/widgets/signature_strip.dart';

/// Label de sección del menú del Perfil (§030.1) — texto sutil
/// bodySmall onSurfaceVariant w600 que encabeza cada grupo de filas
/// ("Mi cuenta", "El negocio"). Vive en la misma geometría straddle
/// que las cards, con padding lateral 14 + superior 8 (tokens del
/// design system) — el texto queda alineado con el contenido interno
/// de las filas que etiqueta.
class ProfileSectionLabel extends StatelessWidget {
  const ProfileSectionLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: LayoutBuilder(
        // Acotado a la franja: el texto "estampado" (onPrimary sobre
        // mostaza) muere negro-sobre-negro si cruza el borde — el
        // ellipsis corta dentro de la franja, overflow visible.
        builder: (context, c) => SizedBox(
          width: c.maxWidth * kSignatureStripFraction,
          child: Padding(
            padding: EdgeInsets.only(
              left: c.maxWidth * kSignatureStripFraction * kCardStripInset + 14,
              right: 8,
            ),
            child: Semantics(
              header: true,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
