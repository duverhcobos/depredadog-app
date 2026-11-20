import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../orders/domain/entities/customer_order.dart';
import '../cubit/admin_queue_state.dart';
import 'admin_chip_band.dart';
import 'admin_filter_chip.dart';

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
    return AdminChipBand(
      children: [
        for (var i = 0; i < lanes.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          AdminFilterChip(
            key: _chipKeys[i],
            label: _laneLabel(l10n, lanes[i]),
            count: widget.state.laneOrders(lanes[i]).length,
            selected: i == widget.index,
            onTap: () => widget.onJump(i),
          ),
        ],
      ],
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
