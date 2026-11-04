import 'package:flutter/material.dart';

import 'signature_strip.dart';

/// Card de sección de personalización (§018): straddle_card de la
/// familia — nace dentro de la franja y desborda al negro, con el
/// título Anton mostaza dentro y sus rows debajo. Reutiliza la
/// geometría compartida de signature_strip.
class CustomizationSection extends StatelessWidget {
  const CustomizationSection({
    required this.title,
    required this.children,
    this.tag,
    super.key,
  });

  final String title;
  final String? tag;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          final strip = c.maxWidth * kSignatureStripFraction;
          return Padding(
            padding: EdgeInsets.only(
              left: strip * kCardStripInset,
              right: blackZoneMargin(c.maxWidth),
            ),
            child: Card(
              margin: EdgeInsets.zero,
              color: colors.surfaceContainerLow,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: text.titleMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (tag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag!,
                              style: text.labelSmall?.copyWith(
                                color: colors.onSecondaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                  ...children,
                  const SizedBox(height: 6),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Row seleccionable (adicionales): nombre + precio + check circular.
/// Tap alterna.
class OptionRow extends StatelessWidget {
  const OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingLabel,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 42,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium,
                ),
              ),
              if (trailingLabel != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    trailingLabel!,
                    style: text.bodySmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
    );
  }
}

/// Row quitable (ingredientes propios): incluido por defecto — tap lo
/// quita (nombre tachado + atenuado) y otro tap lo devuelve. Pan y
/// salchicha nunca aparecen acá (fijos, §018).
class RemovableRow extends StatelessWidget {
  const RemovableRow({
    required this.label,
    required this.removed,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool removed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 42,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    color: removed
                        ? colors.onSurface.withValues(alpha: 0.45)
                        : null,
                    decoration: removed
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: colors.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
              Icon(
                removed
                    ? Icons.remove_circle_outline_rounded
                    : Icons.check_circle_rounded,
                size: 22,
                color: removed ? colors.outlineVariant : colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Píldora seleccionable para opciones gratis ilimitadas (toppings y
/// salsas, §018): llena de mostaza cuando está activa. Se acomodan en
/// Wrap dentro de la CustomizationSection.
class SelectChip extends StatelessWidget {
  const SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: text.bodySmall?.copyWith(
            color: selected ? colors.onPrimary : colors.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Envoltura de SelectChips dentro de la card de sección.
class ChipWrap extends StatelessWidget {
  const ChipWrap({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Wrap(spacing: 8, runSpacing: 8, children: children),
    );
  }
}
