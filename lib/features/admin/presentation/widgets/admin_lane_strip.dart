import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../orders/domain/entities/customer_order.dart';
import '../cubit/admin_queue_state.dart';

/// Strip de carriles del kanban (§036): 5 chips label+count que son
/// también el resumen del tablero ("3 preparando" se ve sin entrar
/// al carril). El chip activo se pinta con el color del carril —
/// semáforo consistente con los chips de estado de la card.
///
/// La BANDA negra (decisión del dueño §036): un bar sólido del
/// negro del scaffold cruza el ancho completo — tapa la franja
/// firma en esta fila, así que el scroll de chips es FULL-WIDTH
/// (el §034c de primario-sobre-mostaza ya no aplica: nada pinta
/// sobre mostaza). Los chips van CENTRADOS: el Row se centra en
/// el viewport cuando cabe; al desbordar, el scroll sigue
/// funcionando y ensureVisible centra el chip del carril activo.
class AdminLaneStrip extends StatefulWidget {
  const AdminLaneStrip({
    required this.state,
    required this.index,
    required this.onJump,
    super.key,
  });

  final AdminQueueState state;
  final int index;
  final ValueChanged<int> onJump;

  @override
  State<AdminLaneStrip> createState() => _AdminLaneStripState();
}

class _AdminLaneStripState extends State<AdminLaneStrip> {
  /// Una llave por chip — ensureVisible lleva el scroll al activo
  /// sin medir anchos (las etiquetas varían por idioma/estado).
  final List<GlobalKey> _chipKeys = [
    for (final _ in AdminQueueState.laneStatuses) GlobalKey(),
  ];

  @override
  void initState() {
    super.initState();
    // Primer frame con índice ≠0 (restauración): centra el activo
    // sin esperar al primer cambio (revisor-ui §036).
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureActiveVisible());
  }

  @override
  void didUpdateWidget(covariant AdminLaneStrip old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _ensureActiveVisible();
  }

  void _ensureActiveVisible() {
    final chipContext = _chipKeys[widget.index].currentContext;
    if (chipContext == null) return;
    Scrollable.ensureVisible(
      chipContext,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      // El activo se centra dentro del viewport full-width.
      alignment: 0.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lanes = AdminQueueState.laneStatuses;
    return Container(
      // La banda — negro puro del scaffold, ancho completo.
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            // minWidth = viewport: el Row se centra cuando los
            // chips caben; al desbordar conserva su ancho real
            // y el scroll horizontal sigue funcionando.
            constraints: BoxConstraints(minWidth: c.maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < lanes.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _LaneChip(
                      key: _chipKeys[i],
                      label: _laneLabel(l10n, lanes[i]),
                      count: widget.state.laneOrders(lanes[i]).length,
                      selected: i == widget.index,
                      onTap: () => widget.onJump(i),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _laneLabel(AppLocalizations l10n, OrderStatus s) => switch (s) {
    OrderStatus.received => l10n.adminStatusPending,
    OrderStatus.confirmed => l10n.orderStatusConfirmed,
    OrderStatus.preparing => l10n.orderStatusPreparing,
    OrderStatus.ready => l10n.orderStatusReady,
    OrderStatus.done => l10n.orderStatusDelivered,
    OrderStatus.cancelled => '',
  };
}

class _LaneChip extends StatelessWidget {
  const _LaneChip({
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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      // Navegación primaria del tablero — el lector anuncia qué
      // carril está activo (precedente segmented_toggle).
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          // Hit area ≥44dp — navegación de uso constante en cocina
          // (misma corrección §034b del filtro).
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.16)
                : colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? colors.primary : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? colors.primary : colors.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? colors.onPrimary : colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
