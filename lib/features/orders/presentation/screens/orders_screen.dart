import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/customization_section.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../cubit/orders_cubit.dart';
import '../cubit/orders_state.dart';
import '../widgets/active_order_card.dart';
import '../widgets/order_history_tile.dart';

/// Tab Pedidos (§027 — datos reales de GET /orders): título naciente
/// + cards straddle por pedido activo (sin heading — el título pelado
/// caía mostaza sobre franja) + CustomizationSection "Historial"
/// (filas-pill → detalle) con "Cargar más" paginado. Loading inicial
/// a spinner; cada pierna del fan-out degrada con su fila inline de
/// error+retry (familia §025). Vacío = ícono + CTA al menú; pull-to-
/// refresh dispara loadOrders real. Es tab — no lleva flecha back.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          BlocBuilder<OrdersCubit, OrdersState>(
            builder: (context, state) {
              if (state.dataLoading) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _OrdersTitle(),
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
              if (state.isEmpty &&
                  !state.activeFailed &&
                  !state.historyFailed) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _OrdersTitle(),
                    // Vacío también refresca — AlwaysScrollable para
                    // que el pull exista aunque no haya scroll
                    // (revisor §027).
                    Expanded(
                      child: RefreshIndicator(
                        color: colors.primary,
                        onRefresh: () =>
                            context.read<OrdersCubit>().loadOrders(),
                        child: LayoutBuilder(
                          builder: (context, c) => ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  left: c.maxWidth * kSignatureStripFraction,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: c.maxHeight,
                                  ),
                                  child: Center(
                                    child: _OrdersEmpty(l10n: l10n),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return RefreshIndicator(
                color: colors.primary,
                onRefresh: () => context.read<OrdersCubit>().loadOrders(),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    const _OrdersTitle(),
                    // Cada pedido activo es su propia straddle_card,
                    // SIN heading "En curso": un título pelado caería
                    // mostaza sobre franja mostaza (la card straddle
                    // invade la franja) y las cards ya se auto-
                    // explican con stepper+chip vivos. La pierna que
                    // falla deja su fila inline de error+retry en el
                    // mismo lugar (familia §025).
                    if (state.activeFailed)
                      _ActiveErrorCard(
                        message: l10n.ordersLoadError,
                        onRetry: () => context.read<OrdersCubit>().loadOrders(),
                      )
                    else
                      for (final order in state.active)
                        ActiveOrderCard(order: order),
                    if (state.historyFailed || state.history.isNotEmpty)
                      CustomizationSection(
                        title: l10n.ordersSectionHistory,
                        children: [
                          if (state.historyFailed)
                            _OrdersErrorRow(
                              message: l10n.ordersLoadError,
                              onRetry: () =>
                                  context.read<OrdersCubit>().loadOrders(),
                            )
                          else ...[
                            for (final order in state.history)
                              OrderHistoryTile(order: order),
                            // Fin del historial paginado: "Cargar más",
                            // mini-spinner en vuelo, o error+retry en la
                            // misma fila si la página falló.
                            if (state.historyLoadMoreFailed)
                              _OrdersErrorRow(
                                message: l10n.ordersLoadMoreError,
                                onRetry: () => context
                                    .read<OrdersCubit>()
                                    .loadMoreHistory(),
                              )
                            else if (state.historyLoadingMore)
                              const _LoadingMoreRow()
                            else if (state.historyHasMore)
                              _LoadMoreRow(
                                onTap: () => context
                                    .read<OrdersCubit>()
                                    .loadMoreHistory(),
                              ),
                          ],
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Título "Pedidos" naciendo de la franja — mismo patrón que
/// `_CartTitle` (FractionallySizedBox en la zona negra, PRIMER hijo
/// del ListView: sale al bajar y reaparece al subir — scrolling_title
/// del design system; en vacío/loading vive fijo en la Column porque
/// no hay scroll).
class _OrdersTitle extends StatelessWidget {
  const _OrdersTitle();

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
              l10n.ordersTitle,
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

/// Vista vacía (§023): recibo + copy de marca + CTA al menú — el
/// mismo motivo del carrito vacío (ícono primary + título + sub +
/// FilledButton).
class _OrdersEmpty extends StatelessWidget {
  const _OrdersEmpty({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 44,
            color: colors.primary.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.ordersEmptyTitle,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.ordersEmptySubtitle,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          // Misma escena que el carrito vacío → misma variante de
          // botón (tonalIcon — revisor-ui §023).
          FilledButton.tonalIcon(
            onPressed: () => context.go(AuthGuard.homeRoute),
            icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
            label: Text(l10n.ordersBrowseMenu),
          ),
        ],
      ),
    );
  }
}

/// Fila inline de error+retry (familia §025 — el aviso de
/// direcciones del checkout): ícono cloud_off + texto + TextButton.
/// Vive dentro de una sección/card existente.
class _OrdersErrorRow extends StatelessWidget {
  const _OrdersErrorRow({required this.message, required this.onRetry});

  final String message;
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
              message,
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

/// La misma fila de error envuelta en la straddle card — ocupa el
/// lugar de las cards activas cuando su pierna falló (no hay heading
/// "En curso" que la contenga).
class _ActiveErrorCard extends StatelessWidget {
  const _ActiveErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, c) => Padding(
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
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _OrdersErrorRow(message: message, onRetry: onRetry),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila "Cargar más" al final del historial — la paginación del
/// bucket history (§027).
class _LoadMoreRow extends StatelessWidget {
  const _LoadMoreRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: TextButton(onPressed: onTap, child: Text(l10n.ordersLoadMore)),
      ),
    );
  }
}

/// Mini-spinner de la misma fila mientras la página siguiente viaja.
class _LoadingMoreRow extends StatelessWidget {
  const _LoadingMoreRow();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Center(
      child: SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}
