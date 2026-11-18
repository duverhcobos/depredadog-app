import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../../orders/domain/entities/customer_order.dart';
import '../../domain/entities/admin_order.dart';
import '../cubit/admin_queue_state.dart';
import 'admin_order_card.dart';

/// Una página-carril del kanban (§036): la lista vertical del estado
/// en FIFO — AnimatedList para que el cambio de carril se LEA (fix
/// UX §040, decisión del dueño: el pedido que avanza o se cancela se
/// desvanece+colapsa ~320ms en vez de teletransportarse, y el que
/// llega crece desde el borde superior; el diff por id vive acá, el
/// cubit solo emite la lista nueva). El carril vacío es una capa en
/// crossfade BAJO la lista: la card saliente se revela sobre ella
/// sin el corte seco del swap de widget. `RefreshIndicator` vive a
/// nivel tablero — el AnimatedList queda AlwaysScrollable para que
/// el gesto alcance también en carriles vacíos, y conserva el
/// primary:true que comparte el inner del NestedScrollView.
class AdminQueueLane extends StatefulWidget {
  const AdminQueueLane({required this.status, required this.state, super.key});

  final OrderStatus status;
  final AdminQueueState state;

  @override
  State<AdminQueueLane> createState() => _AdminQueueLaneState();
}

class _AdminQueueLaneState extends State<AdminQueueLane> {
  static const Duration _moveDuration = Duration(milliseconds: 320);
  static const Duration _emptyFade = Duration(milliseconds: 250);

  final GlobalKey<AnimatedListState> _listKey = GlobalKey();

  /// Espejo local de `state.laneOrders(status)` — la fuente del
  /// itemBuilder. El diff por id (salida/entrada/refresco) corre
  /// contra la lista nueva del cubit en didUpdateWidget.
  late final List<AdminOrder> _orders = List.of(
    widget.state.laneOrders(widget.status),
  );

  @override
  void didUpdateWidget(AdminQueueLane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state, widget.state)) {
      _applyOrders(widget.state.laneOrders(widget.status));
    }
  }

  /// Diff por id entre lo pintado y la lista nueva: los salientes
  /// animan su colapso, los entrantes su entrada y los que quedan
  /// solo refrescan el objeto (ítems hidratados, busy) — conservan
  /// su posición FIFO porque su statusChangedAt no cambia mientras
  /// sigan en el carril.
  void _applyOrders(List<AdminOrder> next) {
    final nextIds = {for (final o in next) o.id};
    for (var i = _orders.length - 1; i >= 0; i--) {
      final removed = _orders[i];
      if (!nextIds.contains(removed.id)) {
        _orders.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _leavingCard(removed, animation),
          duration: _moveDuration,
        );
      }
    }
    for (var i = 0; i < next.length; i++) {
      final incoming = next[i];
      final index = _orders.indexWhere((o) => o.id == incoming.id);
      if (index < 0) {
        _orders.insert(i, incoming);
        _listKey.currentState?.insertItem(i, duration: _moveDuration);
      } else {
        _orders[index] = incoming;
      }
    }
    // Blindaje ante un re-orden del servidor (hoy inalcanzable: el
    // FIFO por statusChangedAt es estable mientras el ítem siga en
    // el carril — si un día cambia, se corrige en vez de divergir).
    if (_orders.length != next.length ||
        !_orders.indexed.every((e) => e.$2.id == next[e.$1].id)) {
      _orders
        ..clear()
        ..addAll(next);
    }
  }

  /// El ítem vivo del carril — envuelto para que su ENTRADA se vea:
  /// crece desde el tope + fade. Los ítems estables reciben la
  /// animación completada (identidad — no cuesta nada por frame).
  Widget _buildItem(
    BuildContext context,
    int index,
    Animation<double> animation,
  ) {
    final order = _orders[index];
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SizeTransition(
        sizeFactor: curved,
        alignment: Alignment.topCenter,
        child: AdminOrderCard(
          order: order,
          busy: widget.state.busyOrderIds.contains(order.id),
        ),
      ),
    );
  }

  /// La card que SALE del carril — colapsa hacia arriba + fade: la
  /// lista se la "traga" suave y las de abajo suben a su lugar.
  /// Recibe el objeto capturado (ya no está en _orders) y queda
  /// IgnorePointer: durante el colapso no puede abrir el detalle
  /// de una orden que ya migró (revisor §040 — ventana muerta).
  Widget _leavingCard(AdminOrder removed, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        ),
        alignment: Alignment.topCenter,
        child: IgnorePointer(child: AdminOrderCard(order: removed)),
      ),
    );
  }

  /// El mensaje del carril vacío — sin scroll propio (el gesto lo
  /// toma el AnimatedList de encima, que sigue scrolleable aunque
  /// no tenga ítems).
  Widget _emptyMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) => Padding(
        // Zona negra — el texto no pinta sobre la franja firma.
        padding: EdgeInsets.only(left: c.maxWidth * kSignatureStripFraction),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.adminLaneEmpty,
              style: text.titleMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Capa del vacío en crossfade — se revela bajo la card que
        // colapsa cuando el carril queda sin pedidos. El mensaje
        // solo EXISTE con el carril vacío: montarlo siempre lo
        // dejaría en el árbol (y en los finders) aunque esté en
        // opacidad 0. IgnorePointer: todo gesto es del list.
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _orders.isEmpty ? 1 : 0,
            duration: _emptyFade,
            child: _orders.isEmpty
                ? _emptyMessage(context)
                : const SizedBox.shrink(),
          ),
        ),
        AnimatedList(
          key: _listKey,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          initialItemCount: _orders.length,
          itemBuilder: _buildItem,
        ),
      ],
    );
  }
}
