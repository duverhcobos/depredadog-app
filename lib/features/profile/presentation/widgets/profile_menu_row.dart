import 'package:flutter/material.dart';

import '../../../home/presentation/widgets/signature_strip.dart';

/// Fila del menú del Perfil (§030): card straddle de la familia con
/// ícono en tile 40px (primaryContainer/onPrimaryContainer), título
/// titleSmall w600, subtítulo opcional y chevron — el equivalente al
/// ListTile de la casa. `destructive` pinta título e ícono en la
/// paleta error y quita el chevron; `opensDialog` también lo quita
/// (el chevron promete navegación, el diálogo no la es).
class ProfileMenuRow extends StatelessWidget {
  const ProfileMenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
    this.opensDialog = false,
    super.key,
  });

  final IconData icon;
  final String title;

  /// Segunda línea opcional (conteo de direcciones, etc.).
  final String? subtitle;
  final VoidCallback onTap;

  /// Variante destructiva — título/ícono error y sin chevron.
  final bool destructive;

  /// La fila abre un diálogo (no navega) — el chevron mentiría el
  /// destino, se oculta igual que en la variante destructiva.
  final bool opensDialog;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: LayoutBuilder(
        builder: (context, c) => Padding(
          // Geometría straddle de la casa: la card nace dentro de la
          // franja y desborda al negro (misma regla que cart/orders).
          padding: EdgeInsets.only(
            left: c.maxWidth * kSignatureStripFraction * kCardStripInset,
            right: blackZoneMargin(c.maxWidth),
          ),
          child: Card(
            margin: EdgeInsets.zero,
            color: colors.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Semantics(
              button: true,
              // Label combinado + textos internos excluidos — sin él
              // TalkBack leía el título dos veces (mismo fix que el
              // botón Carrito del shell, §020).
              label: subtitle != null ? '$title, $subtitle' : title,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: destructive
                              ? colors.errorContainer
                              : colors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: destructive
                              ? colors.onErrorContainer
                              : colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ExcludeSemantics(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: destructive ? colors.error : null,
                                ),
                              ),
                              if (subtitle != null)
                                Text(
                                  subtitle!,
                                  style: text.bodySmall?.copyWith(
                                    color: colors.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (!destructive && !opensDialog) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          // Misma opacidad del chevron del historial —
                          // 0.4 era casi imperceptible (revisor-ui §023).
                          color: colors.onSurface.withValues(alpha: 0.65),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
