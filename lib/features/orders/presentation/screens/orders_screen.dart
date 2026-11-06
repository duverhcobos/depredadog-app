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

/// Tab Pedidos (§023, presentación mock): título naciente + cards
/// straddle por pedido activo (sin heading — el título pelado caía
/// mostaza sobre franja) + CustomizationSection "Historial"
/// (filas-pill → detalle). Vacío = ícono + CTA al menú. Pull-to-
/// refresh simulado (la fuente real es GET /orders del backend 015).
/// Es tab — no lleva flecha back (familia home).
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
              if (state.isEmpty) {
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
                          child: Center(child: _OrdersEmpty(l10n: l10n)),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return RefreshIndicator(
                color: colors.primary,
                onRefresh: () async {
                  // Mock §023 — la integración hace refetch de
                  // GET /orders.
                  await Future<void>.delayed(const Duration(milliseconds: 400));
                },
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    const _OrdersTitle(),
                    // Cada pedido activo es su propia straddle_card,
                    // SIN heading "En curso": un título pelado caería
                    // mostaza sobre franja mostaza (la card straddle
                    // invade la franja) y las cards ya se auto-
                    // explican con stepper+chip vivos.
                    for (final order in state.active)
                      ActiveOrderCard(order: order),
                    if (state.history.isNotEmpty)
                      CustomizationSection(
                        title: l10n.ordersSectionHistory,
                        children: [
                          for (final order in state.history)
                            OrderHistoryTile(order: order),
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
/// del design system; en vacío vive fijo en la Column porque no hay
/// scroll).
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
