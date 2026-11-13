import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../cubit/admin_queue_cubit.dart';
import '../cubit/admin_queue_state.dart';
import '../widgets/admin_order_card.dart';
import '../widgets/admin_queue_filter.dart';

/// Tab Cocina del dueño (§034 — solo presentación, mocks del cubit):
/// la cola de pedidos del local es su pantalla de trabajo diaria,
/// por eso vive a UN CLIC como 4º destino del shell (visible solo
/// con rol admin — el guard y la barra condicional lo garantizan,
/// acá no hay muro de invitado). Familia orders: SignatureStrip +
/// título "Cocina" naciendo del scroll (scrolling_title_tab) +
/// filtro segmentado Activos|Historial + straddle cards por pedido.
/// Estados: spinner de primera carga, vacío por bucket, error +
/// reintentar, pull-to-refresh (la cola se re-consulta — paridad
/// §027). FAB "Nueva orden" ancla el CTA del dueño desde el ciclo 1
/// (form en el ciclo 3 — toast "Disponible próximamente"); tap en
/// card → toast del detalle (ciclo 2). Es tab — no lleva flecha.
class AdminQueueScreen extends StatelessWidget {
  const AdminQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      // El CTA del negocio (decisión del dueño: "órdenes manuales a
      // un clic") — ancla visual desde el ciclo 1 aunque el form de
      // orden presencial llegue en el ciclo 3.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AppToast.info(context, l10n.comingSoon),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.adminNewOrder),
      ),
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          BlocProvider.value(
            value: locator<AdminQueueCubit>(),
            child: BlocBuilder<AdminQueueCubit, AdminQueueState>(
              builder: (context, state) {
                if (state.dataLoading) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _QueueTitle(),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) => Padding(
                            padding: EdgeInsets.only(
                              left: c.maxWidth * kSignatureStripFraction,
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return RefreshIndicator(
                  color: colors.primary,
                  onRefresh: () => context.read<AdminQueueCubit>().load(),
                  child: LayoutBuilder(
                    builder: (context, c) => ListView(
                      // AlwaysScrollable: el pull existe también en
                      // vacío/error (familia orders §027).
                      physics: const AlwaysScrollableScrollPhysics(),
                      // Aire extra al final para que el FAB no tape la
                      // última card.
                      padding: const EdgeInsets.only(bottom: 96),
                      children: [
                        const _QueueTitle(),
                        AdminQueueSegmentedFilter(
                          selected: state.filter,
                          onChanged: (filter) =>
                              context.read<AdminQueueCubit>().setFilter(filter),
                        ),
                        // Error completo SOLO cuando no hay nada que
                        // mostrar (familia §027 — degrada por pierna):
                        // con datos cargados la cola queda pintada y
                        // el fallo baja a fila inline — perder la cola
                        // visible por un error transitorio es peor que
                        // datos algo viejos + retry (revisor-ui). Los
                        // tres estados auxiliares se ACOTAN a la zona
                        // negra (misma geometría del spinner y de la
                        // familia §027): centrados a ancho completo el
                        // texto pintaba sobre la franja mostaza y el
                        // eje quedaba desplazado ~72dp (revisor-ui
                        // §034c).
                        if (state.failed && state.visible.isEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              left: c.maxWidth * kSignatureStripFraction,
                            ),
                            child: _QueueError(
                              minHeight: c.maxHeight - 120,
                              onRetry: () =>
                                  context.read<AdminQueueCubit>().load(),
                            ),
                          )
                        else if (state.visible.isEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              left: c.maxWidth * kSignatureStripFraction,
                            ),
                            child: _QueueEmpty(
                              filter: state.filter,
                              minHeight: c.maxHeight - 120,
                            ),
                          )
                        else ...[
                          if (state.failed)
                            // Mismos márgenes que las cards debajo —
                            // la fila no invade la franja ni sobrepasa
                            // el margen derecho del conjunto.
                            Padding(
                              padding: EdgeInsets.only(
                                left:
                                    c.maxWidth *
                                    kSignatureStripFraction *
                                    kCardStripInset,
                                right: blackZoneMargin(c.maxWidth),
                              ),
                              child: _QueueErrorRow(
                                onRetry: () =>
                                    context.read<AdminQueueCubit>().load(),
                              ),
                            ),
                          for (final order in state.visible)
                            AdminOrderCard(order: order),
                        ],
                      ],
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

/// Título "Cocina" naciendo de la franja — patrón scrolling_title_tab
/// (FractionallySizedBox en la zona negra, PRIMER hijo del ListView:
/// sale al bajar y reaparece al subir — igual que orders/profile).
class _QueueTitle extends StatelessWidget {
  const _QueueTitle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.602,
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
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
        ),
      ),
    );
  }
}

/// Vacío del bucket visible (§034): ícono de la casa + copy de marca.
/// "Sin pedidos activos — la cocina descansa" es el texto aprobado
/// para el bucket vivo; el historial tiene el suyo.
class _QueueEmpty extends StatelessWidget {
  const _QueueEmpty({required this.filter, required this.minHeight});

  final AdminQueueFilter filter;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final active = filter == AdminQueueFilter.active;
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
                active
                    ? l10n.adminQueueEmptyActiveTitle
                    : l10n.adminQueueEmptyHistoryTitle,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                active
                    ? l10n.adminQueueEmptyActiveBody
                    : l10n.adminQueueEmptyHistoryBody,
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

/// Error de la cola (§034) — familia de las vistas de estado de
/// catálogo: ícono + título + sub + FilledButton.tonalIcon
/// "Reintentar" sobre el mismo load.
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
