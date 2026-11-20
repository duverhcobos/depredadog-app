import 'package:flutter/material.dart';

/// Chip de filtro del panel admin — el mismo del strip de carriles
/// del kanban (§036) compartido con la comanda (§042): label +
/// badge de conteo; el activo se pinta mostaza. PULSA cuando su
/// contador cambia (fix UX §040 — en Cocina dice a dónde cayó la
/// card que salió; en la comanda el conteo es estático y el pulso
/// simplemente no dispara). Chip 1→1.06→1 + badge 1→1.22→1 en el
/// mismo reloj; sin rebote en builds sin cambio de conteo.
class AdminFilterChip extends StatefulWidget {
  const AdminFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<AdminFilterChip> createState() => _AdminFilterChipState();
}

class _AdminFilterChipState extends State<AdminFilterChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  late final Animation<double> _chipScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 1, end: 1.06).chain(
        CurveTween(curve: Curves.easeOut),
      ),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.06, end: 1).chain(
        CurveTween(curve: Curves.easeInOut),
      ),
      weight: 60,
    ),
  ]).animate(_pulse);

  late final Animation<double> _badgeScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 1, end: 1.22).chain(
        CurveTween(curve: Curves.easeOut),
      ),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.22, end: 1).chain(
        CurveTween(curve: Curves.easeInOut),
      ),
      weight: 60,
    ),
  ]).animate(_pulse);

  @override
  void didUpdateWidget(covariant AdminFilterChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) _pulse.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      // Filtro/navegación — el lector anuncia qué está activo
      // (precedente segmented_toggle).
      selected: widget.selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: ScaleTransition(
          scale: _chipScale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            // Hit area ≥44dp — uso constante (misma corrección
            // §034b del filtro).
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.selected
                  ? colors.primary.withValues(alpha: 0.16)
                  : colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.selected ? colors.primary : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color:
                        widget.selected ? colors.primary : colors.onSurface,
                  ),
                ),
                const SizedBox(width: 6),
                ScaleTransition(
                  scale: _badgeScale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: widget.selected
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.count}',
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: widget.selected
                            ? colors.onPrimary
                            : colors.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
