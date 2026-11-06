import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../cart/presentation/cubit/cart_cubit.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../../home/presentation/widgets/customization_section.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../cubit/checkout_cubit.dart';
import '../cubit/checkout_state.dart';
import '../widgets/order_summary_block.dart';
import '../widgets/order_type_body.dart';
import '../widgets/order_type_toggle.dart';
import '../widgets/payment_block.dart';

/// Checkout (§022, solo presentación): familia del carrito/detalle —
/// franja firma + título naciente dentro del scroll + cards straddle
/// por sección + footer fijo. Vive DENTRO del shell
/// (/home/cart/checkout, hija de cart — conserva header y nav).
///
/// Secciones: tipo de pedido (toggle + local/ubicaciones + form nueva
/// — puntos de referencia + pin de Google, domicilio GRATIS §022a),
/// observación, pago (logo Nequi + celular prellenado editable / al
/// recibir) y resumen con totales. Confirmar valida INLINE (ubicación
/// en domicilio, celular Nequi válido — SIN mínimo), hace el delay
/// mock de 800ms y abre el diálogo de éxito: "Ver mis pedidos" vacía
/// el carrito y va a /orders (flujo completo simulado — la integración
/// real llega por endpoint).
class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  /// Diálogo de éxito (PROVISIONAL — §022): SIN número de orden
  /// (§022b — el consecutivo revela el volumen de ventas del negocio;
  /// el cliente solo necesita saber que su pedido quedó).
  void _showConfirmedDialog(BuildContext context, CheckoutState state) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      // El único camino es el CTA — no se cierra por fuera.
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        // Ícono de marca (imagotipo) — elemento firma como en
        // verify-email, no un Material icon genérico. Decorativo
        // para TalkBack: el título ya lo describe.
        icon: ExcludeSemantics(
          child: Image.asset(
            Theme.of(dialogContext).brightness == Brightness.dark
                ? 'assets/images/imagotipo_depredadog_dark.png'
                : 'assets/images/imagotipo_depredadog.png',
            height: 72,
            fit: BoxFit.contain,
          ),
        ),
        title: Text(l10n.checkoutConfirmedTitle, textAlign: TextAlign.center),
        content: Text(
          l10n.checkoutConfirmedSubtitle,
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.maxFinite,
            child: FilledButton(
              onPressed: () {
                // Capturados antes de navegar: tras el go la pantalla
                // queda desactivada.
                final router = GoRouter.of(context);
                final cart = context.read<CartCubit>();
                Navigator.of(dialogContext).pop();
                // Flujo simulado de punta a punta (§022): el vaciado
                // real lo hará la integración de POST /orders (§015).
                cart.clear();
                // Reencauza la branch de Inicio a su raíz (suelta
                // carrito+checkout del stack) y UN FRAME DESPUÉS salta
                // a Pedidos — pops/go en el mismo frame compiten entre
                // sí y dejaban un checkout fantasma con carrito vacío
                // al volver al tab (revisor-ui).
                router.go(AuthGuard.homeRoute);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  router.go(AuthGuard.ordersRoute);
                });
              },
              child: Text(l10n.checkoutViewOrdersCta),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return BlocListener<CheckoutCubit, CheckoutState>(
      listenWhen: (prev, curr) => !prev.orderConfirmed && curr.orderConfirmed,
      listener: _showConfirmedDialog,
      child: BlocBuilder<CheckoutCubit, CheckoutState>(
        builder: (context, state) {
          // El total mezcla carrito + tipo de pedido — se lee de ambos
          // (el carrito no cambia mientras el checkout está abierto,
          // pero el watch lo mantiene correcto por construcción).
          final subtotal = context.watch<CartCubit>().state.subtotal;
          final total =
              subtotal +
              (state.orderType == CheckoutOrderType.delivery
                  ? state.store.deliveryFee
                  : 0);
          return Scaffold(
            // Convención de loading (elevated_button_primary): TODOS
            // los controles se bloquean durante la confirmación sin
            // atenuar — incluida la flecha back.
            body: IgnorePointer(
              ignoring: state.confirmInProgress,
              child: Stack(
                children: [
                  const SignatureStrip(fraction: kSignatureStripFraction),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          children: [
                            const _CheckoutTitle(),
                            CustomizationSection(
                              title: l10n.checkoutOrderTypeSection,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    10,
                                    14,
                                    4,
                                  ),
                                  child: OrderTypeToggle(
                                    orderType: state.orderType,
                                    onChanged: context
                                        .read<CheckoutCubit>()
                                        .setOrderType,
                                  ),
                                ),
                                const OrderTypeBody(),
                              ],
                            ),
                            // Observación justo bajo Tipo de pedido
                            // (§022a — decisión del usuario): la nota
                            // del pedido va antes del pago.
                            CustomizationSection(
                              title: l10n.checkoutNoteSection,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    10,
                                    14,
                                    8,
                                  ),
                                  child: TextField(
                                    minLines: 2,
                                    maxLines: 4,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: InputDecoration(
                                      hintText: l10n.checkoutNoteHint,
                                    ),
                                    onChanged: context
                                        .read<CheckoutCubit>()
                                        .noteChanged,
                                  ),
                                ),
                              ],
                            ),
                            CustomizationSection(
                              title: l10n.checkoutPaymentSection,
                              children: const [PaymentBlock()],
                            ),
                            CustomizationSection(
                              title: l10n.checkoutSummarySection,
                              children: const [OrderSummaryBlock()],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                      // Footer fijo — mismo patrón del carrito/detalle:
                      // fondo opaco para que la franja no se filtre.
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
                                      l10n.detailTotalLabel,
                                      style: text.bodySmall?.copyWith(
                                        color: colors.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      formatCop(total),
                                      style: text.titleMedium?.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: FilledButton(
                                    // Spinner DENTRO del botón
                                    // (elevated_button_primary): el
                                    // CTA sigue mostaza y el cubit
                                    // ignora re-entradas.
                                    onPressed: context
                                        .read<CheckoutCubit>()
                                        .confirm,
                                    child: state.confirmInProgress
                                        ? SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: colors.onPrimary,
                                            ),
                                          )
                                        : Text(l10n.checkoutConfirmCta),
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
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: colors.onPrimary,
                      ),
                      tooltip: l10n.catalogBackTooltip,
                      onPressed: () => context.pop(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Título "Confirmar pedido" naciendo de la franja — patrón
/// scrolling_title (mismo del carrito/detalle, dentro del scroll).
class _CheckoutTitle extends StatelessWidget {
  const _CheckoutTitle();

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
              l10n.checkoutTitle,
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
