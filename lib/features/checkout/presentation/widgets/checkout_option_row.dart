import 'package:flutter/material.dart';

/// Fila seleccionable del checkout (§022): ícono + título (+ subtítulo
/// opcional) + círculo de selección — mismo idioma que `OptionRow` del
/// detalle (radio vacío outlineVariant → check_circle_rounded primary),
/// aquí con leading icon porque las opciones son de distinta especie
/// (dirección guardada, Nequi, contra entrega).
class CheckoutOptionRow extends StatelessWidget {
  const CheckoutOptionRow({
    this.icon,
    this.leading,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    super.key,
  }) : assert(
         icon != null || leading != null,
         'CheckoutOptionRow necesita icon o leading',
       );

  /// Ícono Material de la fila (teñido primary al seleccionar). Para
  /// marcas con identidad propia — el logo de Nequi — usar [leading].
  final IconData? icon;

  /// Widget a la izquierda que reemplaza al [icon] teñido — logos de
  /// marca conservan sus colores (§022a: tile blanco + SVG Nequi).
  final Widget? leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      // Estado de selección para TalkBack — la fila actúa como
      // radio dentro de su grupo (revisor-ui).
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          // Hit area mínima de 44dp también en filas de una línea.
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                leading ??
                    Icon(
                      icon,
                      size: 20,
                      color: selected
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.5),
                    ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: selected ? colors.primary : colors.outlineVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
