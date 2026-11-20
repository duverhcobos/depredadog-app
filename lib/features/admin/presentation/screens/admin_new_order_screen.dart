import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../cubit/admin_new_order_cubit.dart';
import '../cubit/admin_new_order_state.dart';
import '../cubit/admin_queue_cubit.dart';
import '../widgets/new_order/cobro_step.dart';
import '../widgets/new_order/comanda_step.dart';
import '../widgets/new_order/new_order_error_view.dart';

/// Comanda presencial del dueño (§042): la pantalla con la que toma
/// pedidos de mesa y de mostrador y los manda a la cola kanban —
/// POST /admin/orders real. Una ruta, dos pasos internos
/// (comanda → cobro) dentro del mismo cubit factory (el borrador
/// nace y muere con la visita). Lenguaje: firma de marca (franja +
/// flecha onPrimary + título naciente + footer fijo opaco) — mismo
/// idioma visual del cierre §036/detalle §035.
class AdminNewOrderScreen extends StatefulWidget {
  const AdminNewOrderScreen({super.key});

  @override
  State<AdminNewOrderScreen> createState() => _AdminNewOrderScreenState();
}

class _AdminNewOrderScreenState extends State<AdminNewOrderScreen> {
  @override
  void initState() {
    super.initState();
    // Carta + mesas en paralelo al entrar (§042).
    context.read<AdminNewOrderCubit>().load();
  }

  /// Flecha/back nativo — comanda sale a Cocina (pop); cobro
  /// devuelve al paso comanda sin perder el borrador (step
  /// interno, §042). Durante el submit no hace nada: la pantalla
  /// entera está bloqueada (IgnorePointer + PopScope).
  void _onBack() {
    final cubit = context.read<AdminNewOrderCubit>();
    if (cubit.state.submitting) return;
    if (cubit.state.step == AdminNewOrderStep.cobro) {
      cubit.backToComanda();
    } else {
      context.pop();
    }
  }

  /// "Crear pedido" — el cubit devuelve orden o failure y la
  /// pantalla tosteea por errorCode (mapa §042): catálogo violado,
  /// mesa stale (ya se resincronizó sola), dispatch transfer fallido
  /// o genérico. Éxito → toast con el consecutivo + resync de la
  /// cola + pop a Cocina (la card llega animada por el diff).
  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await context.read<AdminNewOrderCubit>().submit();
    // El resync de la cola NO depende del mounted: si el pop ya
    // corrió, la orden igual existe y la cola debe reflejarla
    // (revisor-ui §042 — antes quedaba stale en ese caso borde).
    final order = result.order;
    if (order != null) {
      locator<AdminQueueCubit>().load();
      if (!mounted) return;
      AppToast.success(
        context,
        l10n.adminNewOrderCreated(order.orderNumber ?? 0),
      );
      context.pop();
      return;
    }
    if (!mounted) return;
    final failure = result.failure;
    if (failure == null) return; // canSubmit guard — el CTA ya lo cubre
    AppToast.error(context, switch (failure.errorCode) {
      'ORDER_CATALOG_VIOLATION' => l10n.adminNewOrderCatalogViolation,
      'TABLE_NOT_FOUND' => l10n.adminNewOrderTableStale,
      'PAYMENT_DISPATCH_FAILED' => l10n.adminNewOrderDispatchFailed,
      _ => l10n.adminToastActionFailed,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    // El back nativo corre el MISMO camino que la flecha (cobro →
    // comanda, comanda → pop) — sin él la ruta entera salía y la
    // comanda armada se destruía en silencio (revisor-ui §042).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: BlocSelector<AdminNewOrderCubit, AdminNewOrderState, bool>(
          selector: (state) => state.submitting,
          builder: (context, submitting) => IgnorePointer(
            // Submit en vuelo: pantalla entera bloqueada — chips,
            // steppers, campos, flecha (convención register; el
            // PopScope de arriba cubre el back nativo).
            ignoring: submitting,
            child: Stack(
              children: [
                const SignatureStrip(fraction: kSignatureStripFraction),
                Column(
                  children: [
                    Expanded(
                      child:
                          BlocBuilder<AdminNewOrderCubit, AdminNewOrderState>(
                            builder: (context, state) {
                              if (state.loading) {
                                return LayoutBuilder(
                                  builder: (context, c) => Padding(
                                    padding: EdgeInsets.only(
                                      left:
                                          c.maxWidth * kSignatureStripFraction,
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: colors.primary,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (state.failed) {
                                return NewOrderErrorView(
                                  onRetry: () =>
                                      context.read<AdminNewOrderCubit>().load(),
                                );
                              }
                              // Dos pasos, una ruta — la transición queda
                              // dentro de la pantalla (§042).
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: state.step == AdminNewOrderStep.comanda
                                    ? const ComandaStep(
                                        key: ValueKey('comanda'),
                                      )
                                    : const CobroStep(key: ValueKey('cobro')),
                              );
                            },
                          ),
                    ),
                    // Footer fijo opaco full-width (patrón §035): comanda
                    // → "N ítems · $total → Continuar" (disabled si 0);
                    // cobro → "Crear pedido · $total" (spinner en busy).
                    // Oculto en loading/failed — un CTA "0 ítems"
                    // disabled bajo el spinner/error es ruido
                    // (revisor-ui §042).
                    BlocSelector<AdminNewOrderCubit, AdminNewOrderState, bool>(
                      selector: (state) => state.loading || state.failed,
                      builder: (context, unavailable) {
                        if (unavailable) return const SizedBox.shrink();
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border(
                              top: BorderSide(color: colors.outlineVariant),
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: SafeArea(
                              top: false,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  12,
                                ),
                                child: BlocBuilder<AdminNewOrderCubit, AdminNewOrderState>(
                                  // El footer solo recompone con lo
                                  // que pinta — un keystroke de la
                                  // nota/celular no lo reconstruye.
                                  buildWhen: (p, c) =>
                                      p.items != c.items ||
                                      p.step != c.step ||
                                      p.canSubmit != c.canSubmit ||
                                      p.submitting != c.submitting,
                                  builder: (context, state) {
                                    final inComanda =
                                        state.step == AdminNewOrderStep.comanda;
                                    // Patrón §035: durante el submit
                                    // el botón NO se apaga a gris —
                                    // queda primary con el spinner
                                    // onPrimary visible; el
                                    // IgnorePointer externo ya bloquea
                                    // los taps y el cubit corta la
                                    // re-entrada con su canSubmit.
                                    final enabled = inComanda
                                        ? state.itemCount > 0
                                        : state.canSubmit || state.submitting;
                                    final text = Theme.of(context).textTheme;
                                    // Footer del carrito (§020):
                                    // resumen a la izquierda
                                    // (conteo + total) y la ACCIÓN
                                    // limpia a la derecha — el
                                    // dato y el CTA no se funden
                                    // en un solo botón (decisión
                                    // del dueño §042).
                                    return Row(
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l10n.adminNewOrderItems(
                                                state.itemCount,
                                              ),
                                              style: text.bodySmall?.copyWith(
                                                color: colors.onSurface
                                                    .withValues(alpha: 0.7),
                                              ),
                                            ),
                                            Text(
                                              formatCop(state.total),
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
                                            onPressed: enabled
                                                ? (inComanda
                                                      ? () => context
                                                            .read<
                                                              AdminNewOrderCubit
                                                            >()
                                                            .goToCobro()
                                                      : _submit)
                                                : null,
                                            child:
                                                !inComanda && state.submitting
                                                ? SizedBox(
                                                    height: 18,
                                                    width: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color:
                                                              colors.onPrimary,
                                                        ),
                                                  )
                                                : Text(
                                                    inComanda
                                                        ? l10n.adminNewOrderContinue
                                                        : l10n.adminNewOrderCreate,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                // Flecha sobre la franja — onPrimary negro sobre mostaza
                // (misma geometría del detalle §035 / cierre §036).
                Positioned(
                  top: 12,
                  left: 4,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: colors.onPrimary,
                    ),
                    tooltip: l10n.catalogBackTooltip,
                    onPressed: _onBack,
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
