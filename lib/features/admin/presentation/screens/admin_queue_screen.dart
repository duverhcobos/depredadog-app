import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/routes/auth_guard.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../cubit/admin_queue_cubit.dart';
import '../cubit/admin_queue_state.dart';
import '../widgets/admin_lane_strip.dart';
import '../widgets/admin_queue_lane.dart';

/// Tab Cocina del dueño (§036 kanban; §038 la cola es real — GET
/// /admin/orders active+history; §039 el detalle hidrata modifiers):
/// la cola deja de ser lista+filtro y se vuelve un KANBAN de 5
/// carriles (Pendiente | Confirmado | Preparando | Listo | Entregado)
/// — un carril por página del PageView, navegación por swipe o por
/// tap en el strip de chips con contadores FIJADO arriba. El pedido
/// `done` ya no sale de Cocina: vive en el carril Entregado hasta el
/// CIERRE DE CAJA manual (botón caja + badge de entregados al frente
/// del header — decisión del dueño — → /admin/day-close); solo el
/// cancelado cruza al historial de una (ícono 🕐 → /admin/history).
/// HEADER EN EL SCROLL (decisión del dueño §036): caja + título +
/// historial colapsan con el contenido y solo vuelven cuando el
/// PRIMER pedido llega al tope y los empuja (sin float — un
/// toquecito no los reflota); el strip de carriles se queda
/// fijado (el tablero nunca pierde su navegación). Con carril
/// profundo aparece una flecha "volver"
/// sobre el FAB que regresa lista + header al inicio. Estados:
/// spinner de primera carga, vacío global, error + reintentar,
/// pull-to-refresh (overscroll del outer, depth 0). FAB "Nueva
/// orden" ancla el CTA del dueño (form en el ciclo 3 — toast
/// "Disponible próximamente"); tap en card → detalle /admin/:id.
/// Es tab — no lleva flecha.
class AdminQueueScreen extends StatefulWidget {
  const AdminQueueScreen({super.key});

  @override
  State<AdminQueueScreen> createState() => _AdminQueueScreenState();
}

class _AdminQueueScreenState extends State<AdminQueueScreen> {
  /// PageController del kanban — un carril a la vez (viewport
  /// completo); el strip salta con animateToPage y el swipe actualiza
  /// _pageIndex para resaltar el chip activo.
  final PageController _pageController = PageController();
  int _pageIndex = 0;

  /// Outer del NestedScrollView — la posición del colapso del
  /// header (0 = header abierto). El "volver al inicio" la regresa
  /// a 0 además de las listas internas.
  final ScrollController _outerController = ScrollController();

  /// Inner del NestedScrollView — capturado del PrimaryScrollController
  /// del body (es el _NestedScrollController compartido por las
  /// ListViews de los carriles, que lo usan vía primary:true).
  ScrollController? _innerController;

  /// Flecha "volver al inicio" visible — solo con carril profundo
  /// (decisión del dueño: aparece sobre el FAB al hacer mucho scroll).
  bool _showBackToTop = false;

  /// Profundidad de scroll que dispara la flecha — ~2 cards de alto.
  static const double _backToTopThreshold = 560;

  @override
  void dispose() {
    _pageController.dispose();
    _outerController.dispose();
    super.dispose();
  }

  void _jumpToLane(int i) => _pageController.animateToPage(
    i,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  /// Rastrea el scroll del carril activo para la flecha: dentro del
  /// NestedScrollView las notificaciones de las ListViews llegan con
  /// depth ≥2 (PageView + outer scrollable entre ellas y el listener).
  bool _trackLaneScroll(ScrollNotification notification) {
    if (notification.depth >= 2 &&
        notification.metrics.axis == Axis.vertical) {
      final show = notification.metrics.pixels > _backToTopThreshold;
      if (show != _showBackToTop) setState(() => _showBackToTop = show);
    }
    return false;
  }

  /// "Volver al inicio": sube el carril visible (y sus vecinos —
  /// posiciones del inner compartido) y reabre el header.
  void _scrollToTop() {
    const duration = Duration(milliseconds: 250);
    final positions =
        _innerController?.positions ?? const <ScrollPosition>[];
    for (final position in positions) {
      unawaited(
        position.animateTo(0, duration: duration, curve: Curves.easeOut),
      );
    }
    if (_outerController.hasClients) {
      unawaited(
        _outerController.animateTo(
          0,
          duration: duration,
          curve: Curves.easeOut,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      // El CTA del negocio (decisión del dueño: "órdenes manuales a
      // un clic") — ícono solo; el texto sobraba en el chrome (§036).
      // Encima flota la flecha "volver al inicio" cuando el carril
      // va profundo (decisión del dueño — tonal, no compite con el +).
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: _showBackToTop
                ? Padding(
                    key: const ValueKey('backToTop'),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FloatingActionButton.small(
                      heroTag: 'backToTop',
                      onPressed: _scrollToTop,
                      backgroundColor: colors.surfaceContainerHigh,
                      foregroundColor: colors.primary,
                      tooltip: l10n.adminBackToTop,
                      child: const Icon(Icons.keyboard_arrow_up_rounded),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('noBackToTop')),
          ),
          FloatingActionButton(
            onPressed: () => AppToast.info(context, l10n.comingSoon),
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            tooltip: l10n.adminNewOrder,
            child: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          BlocProvider.value(
            value: locator<AdminQueueCubit>(),
            child: BlocBuilder<AdminQueueCubit, AdminQueueState>(
              builder: (context, state) {
                // TODO dentro del MISMO scroll (decisión del dueño):
                // el header colapsa/reabre con el contenido y el
                // strip de carriles queda fijado arriba.
                return NotificationListener<ScrollNotification>(
                  onNotification: _trackLaneScroll,
                  child: RefreshIndicator(
                    color: colors.primary,
                    // Con NestedScrollView el overscroll puede llegar
                    // por inner u outer según dónde caiga el tope —
                    // sin filtro de depth; el indicador solo responde
                    // a overscroll en el borde superior de todas
                    // maneras. La cláusula de eje excluye el strip.
                    notificationPredicate: (notification) =>
                        notification.metrics.axis == Axis.vertical,
                    onRefresh: () =>
                        context.read<AdminQueueCubit>().load(),
                    child: NestedScrollView(
                      controller: _outerController,
                      // SIN float (decisión del dueño §036): el
                      // header solo vuelve cuando el PRIMER pedido
                      // llega al tope y lo empuja hacia abajo —
                      // un toquecito hacia arriba no lo reflota.
                      floatHeaderSlivers: false,
                      headerSliverBuilder: (context, innerBoxIsScrolled) => [
                        SliverToBoxAdapter(
                          child: _QueueHeader(
                            deliveredCount: state.deliveredCount,
                            onHistory: () => context
                                .push('${AuthGuard.adminRoute}/history'),
                            onCloseDay: () => context
                                .push('${AuthGuard.adminRoute}/day-close'),
                          ),
                        ),
                      ],
                      body: Builder(
                        builder: (context) {
                          // El inner compartido (primary de las
                          // ListViews de carril) — para _scrollToTop.
                          _innerController =
                              PrimaryScrollController.of(context);
                          return Column(
                            children: [
                              // Strip "fijado" como FILA del body:
                              // ocupa layout (no overlay) — siempre
                              // arriba con el header colapsado y las
                              // cards nunca pasan debajo. Banda
                              // negra + chips centrados (decisión
                              // del dueño §036). Solo existe con
                              // tablero — en vacío/error sus chips
                              // "0" eran affordance falsa
                              // (revisor-ui §036).
                              if (!state.dataLoading &&
                                  state.active.isNotEmpty)
                                AdminLaneStrip(
                                  state: state,
                                  index: _pageIndex,
                                  onJump: _jumpToLane,
                                ),
                              // Error con datos cargados: fila inline
                              // fija sobre el tablero (perder la cola
                              // por un fallo transitorio es peor —
                              // revisor-ui §034).
                              if (state.failed && state.active.isNotEmpty)
                                LayoutBuilder(
                                  builder: (context, c) => Padding(
                                    padding: EdgeInsets.only(
                                      left: c.maxWidth *
                                          kSignatureStripFraction *
                                          kCardStripInset,
                                      right: blackZoneMargin(c.maxWidth),
                                    ),
                                    child: _QueueErrorRow(
                                      onRetry: () => context
                                          .read<AdminQueueCubit>()
                                          .load(),
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: state.dataLoading
                                    ? LayoutBuilder(
                                        builder: (context, c) => Padding(
                                          padding: EdgeInsets.only(
                                            left: c.maxWidth *
                                                kSignatureStripFraction,
                                          ),
                                          child: Center(
                                            child:
                                                CircularProgressIndicator(
                                              color: colors.primary,
                                            ),
                                          ),
                                        ),
                                      )
                                    : _QueueBoard(
                                        state: state,
                                        controller: _pageController,
                                        onPageChanged: (i) => setState(() {
                                          _pageIndex = i;
                                          // El carril nuevo arranca
                                          // fresco — la flecha refleja
                                          // SU scroll, no el del viejo.
                                          _showBackToTop = false;
                                        }),
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// El tablero del kanban: el PageView de carriles o, cuando TODOS
/// los carriles están vacíos (o el load falló sin datos), el estado
/// global — envuelto en scroll para que el pull-to-refresh alcance
/// también desde el vacío/error (familia orders §027).
class _QueueBoard extends StatelessWidget {
  const _QueueBoard({
    required this.state,
    required this.controller,
    required this.onPageChanged,
  });

  final AdminQueueState state;
  final PageController controller;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (state.failed && state.active.isEmpty) {
      return LayoutBuilder(
        builder: (context, c) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(left: c.maxWidth * kSignatureStripFraction),
          children: [
            _QueueError(
              minHeight: c.maxHeight,
              onRetry: () => context.read<AdminQueueCubit>().load(),
            ),
          ],
        ),
      );
    }
    if (state.active.isEmpty) {
      return LayoutBuilder(
        builder: (context, c) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(left: c.maxWidth * kSignatureStripFraction),
          children: [_QueueEmpty(minHeight: c.maxHeight)],
        ),
      );
    }
    return PageView(
      controller: controller,
      onPageChanged: onPageChanged,
      children: [
        for (final s in AdminQueueState.laneStatuses)
          AdminQueueLane(status: s, state: state),
      ],
    );
  }
}

/// Header del tablero (§036): vive en el scroll — colapsa al bajar
/// y solo vuelve con el primer pedido al tope (sin float), decisión
/// del dueño. El
/// botón de caja va AL FRENTE (leading) FLOTANDO sobre la franja
/// firma como las imágenes de las cards; el título mostaza y el
/// ícono de historial viven en la zona negra (el texto mostaza no
/// puede pintar sobre mostaza).
class _QueueHeader extends StatelessWidget {
  const _QueueHeader({
    required this.deliveredCount,
    required this.onHistory,
    required this.onCloseDay,
  });

  final int deliveredCount;
  final VoidCallback onHistory;
  final VoidCallback onCloseDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) => Padding(
        padding: const EdgeInsets.only(top: 8, right: 8),
        child: Row(
          children: [
            // Slot del ancho de la franja (o el mínimo que el botón
            // necesita para conservar toda su área de toque en
            // pantallas angostas — UnconstrainedBox deja que el
            // botón straddee el límite mostaza/negro como las
            // imágenes de las cards).
            SizedBox(
              // El cierre vive SOBRE la franja — ícono solo +
              // badge de notificación con los entregados (decisión
              // del dueño: ni siquiera "Caja" — el glifo basta). El
              // slot vale 0.398 del ancho — el MISMO origen del
              // título naciente de todas las pantallas (widthFactor
              // 0.602 calibrado por el usuario): el título nace 2px
              // dentro de la franja, pegado de verdad.
              width: math.max(c.maxWidth * 0.398, 96),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Badge(
                    isLabelVisible: deliveredCount > 0,
                    label: Text('$deliveredCount'),
                    child: IconButton.filledTonal(
                      onPressed: onCloseDay,
                      icon: const Icon(Icons.point_of_sale_rounded),
                      tooltip: l10n.adminDayCloseTitle,
                    ),
                  ),
                ),
              ),
            ),
            // El título nace en 0.398 del ancho — PEGADO al filo
            // de la franja igual que todos los títulos nacientes.
            Expanded(
              child: Text(
                l10n.adminQueueTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.headlineSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: onHistory,
              icon: const Icon(Icons.history_rounded),
              tooltip: l10n.adminHistoryTitle,
            ),
          ],
        ),
      ),
    );
  }
}

/// Vacío global del tablero (§036): solo aplica cuando TODOS los
/// carriles están vacíos — un carril sin pedidos muestra su propio
/// empty compacto dentro del PageView. Ícono de la casa + copy de
/// marca aprobado ("la cocina descansa").
class _QueueEmpty extends StatelessWidget {
  const _QueueEmpty({required this.minHeight});

  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                // Mismo glifo del destino del nav — espeja la sección
                // que vacía (convención del muro/empty de orders).
                Icons.soup_kitchen_outlined,
                size: 44,
                color: colors.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.adminQueueEmptyActiveTitle,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.adminQueueEmptyActiveBody,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila inline de error+retry (familia _OrdersErrorRow §027) — el
/// fallo con datos cargados: ícono cloud_off + mensaje + TextButton.
class _QueueErrorRow extends StatelessWidget {
  const _QueueErrorRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 4),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.adminQueueLoadError,
              style: text.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l10n.ordersRetry)),
        ],
      ),
    );
  }
}

/// Error del tablero (familia de las vistas de estado de catálogo):
/// ícono + título + sub + FilledButton.tonalIcon "Reintentar" sobre
/// el mismo load.
class _QueueError extends StatelessWidget {
  const _QueueError({required this.minHeight, required this.onRetry});

  final double minHeight;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.adminQueueLoadError,
                textAlign: TextAlign.center,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.catalogLoadErrorSubtitle,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.ordersRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
