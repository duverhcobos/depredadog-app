import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/routes/auth_guard.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/store_closed_message.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../../store/domain/entities/store_open_state.dart';
import '../../../store/presentation/cubit/store_status_cubit.dart';
import '../../domain/entities/cart_item.dart';
import '../cubit/cart_cubit.dart';
import '../cubit/cart_state.dart';
import '../widgets/cart_browse_more_card.dart';
import '../widgets/cart_empty_view.dart';
import '../widgets/cart_item_tile.dart';

/// Carrito (§020): familia del detalle — franja firma + título
/// naciente dentro del scroll + cards straddle por ítem + footer
/// fijo. Vive DENTRO del shell (/home/cart): header y nav bar se
/// conservan. Tres vías de eliminar una fila: swipe endToStart,
/// − del stepper en 1, y el ícono de basura del tile (affordance
/// + accesibilidad, revisor-ui §020) — todas con toast de feedback.
///
/// El CTA "Ir a pagar" hace push a /home/cart/checkout (§022 —
/// conserva el stack: volver del checkout regresa al carrito).
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    // §029 — estado del local fresco al entrar al carrito: la
    // compuerta del "Ir a pagar" no puede mostrar un dato viejo.
    // Guard igual que el reload de OrdersCubit del shell (tests
    // aislados sin DI no deben reventar).
    if (locator.isRegistered<StoreStatusCubit>()) {
      locator<StoreStatusCubit>().refresh();
    }
  }

  /// Elimina el ítem y avisa — el toast es el feedback mínimo ante
  /// una destrucción sin deshacer (revisor-ui §020; el undo/banner
  /// queda como pendiente de UX).
  void _removeItem(BuildContext context, CartItem item) {
    context.read<CartCubit>().removeItem(item.id);
    AppToast.info(
      context,
      AppLocalizations.of(context)!.cartItemRemoved(item.productName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        return Scaffold(
          body: Stack(
            children: [
              const SignatureStrip(fraction: kSignatureStripFraction),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: state.isEmpty
                        // Vacío: no hay scroll que hacer — Column
                        // fija + el view centrado de verdad dentro
                        // de la zona NEGRA (revisor-ui §020: el
                        // Center dentro de un ListView no centra).
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _CartTitle(),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, c) => Padding(
                                    padding: EdgeInsets.only(
                                      left:
                                          c.maxWidth * kSignatureStripFraction,
                                    ),
                                    child: Center(
                                      child: CartEmptyView(
                                        onBrowse: () =>
                                            context.go(AuthGuard.homeRoute),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              const _CartTitle(),
                              for (final item in state.items)
                                Dismissible(
                                  key: ValueKey(item.id),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (_) =>
                                      _removeItem(context, item),
                                  background: Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 24),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        color: colors.error,
                                      ),
                                    ),
                                  ),
                                  child: CartItemTile(
                                    item: item,
                                    // q<=0 (stepper en 1) elimina —
                                    // va por _removeItem para que
                                    // también salga el toast.
                                    onQuantityChanged: (q) => q <= 0
                                        ? _removeItem(context, item)
                                        : context
                                              .read<CartCubit>()
                                              .updateQuantity(item.id, q),
                                    onRemove: () => _removeItem(context, item),
                                  ),
                                ),
                              // Cierre de lista: ghost card que
                              // invita a seguir pidiendo (decisión
                              // del usuario — revisor-estetico §020).
                              const CartBrowseMoreCard(),
                              const SizedBox(height: 24),
                            ],
                          ),
                  ),
                  // Footer fijo — mismo patrón del detalle: fondo
                  // opaco para que la franja no se filtre.
                  if (!state.isEmpty)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(
                          top: BorderSide(color: colors.outlineVariant),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.cartSubtotalLabel,
                                    style: text.bodySmall?.copyWith(
                                      color: colors.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatCop(state.subtotal),
                                    style: text.titleMedium?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              // §029 — solo `closed` CONFIRMADO
                              // reemplaza el CTA por el mensaje:
                              // unknown (sin consultar/falló) deja
                              // pasar — el checkout tiene compuerta
                              // propia con retry y el backend es la
                              // última línea.
                              Expanded(
                                child:
                                    BlocBuilder<
                                      StoreStatusCubit,
                                      StoreOpenState
                                    >(
                                      builder: (context, status) =>
                                          status == StoreOpenState.closed
                                          ? StoreClosedMessage(
                                              message: l10n.cartStoreClosed,
                                            )
                                          : FilledButton(
                                              // §022: push (no go) —
                                              // volver del checkout
                                              // regresa al carrito con
                                              // sus ítems intactos.
                                              onPressed: () => context.push(
                                                AuthGuard.checkoutRoute,
                                              ),
                                              child: Text(l10n.cartCheckoutCta),
                                            ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Positioned(
                top: 12,
                left: 4,
                child: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: colors.onPrimary),
                  tooltip: l10n.catalogBackTooltip,
                  onPressed: () => context.pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Título "Tu carrito" naciendo de la franja — mismo motivo del
/// detalle (decisión del usuario, dentro del scroll).
class _CartTitle extends StatelessWidget {
  const _CartTitle();

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
              l10n.cartTitle,
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
