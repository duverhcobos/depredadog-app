import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../domain/entities/admin_order.dart';
import '../cubit/admin_new_order_cubit.dart';
import '../cubit/admin_new_order_state.dart';
import '../cubit/admin_queue_cubit.dart';
import '../utils/kitchen_order_data.dart';
import '../widgets/kitchen_item_card.dart';
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
  /// interno, §042). En la vista de éxito el back es pop directo:
  /// el pedido ya existe y la regla cobro→comanda no aplica (§043).
  /// Durante el submit no hace nada: la pantalla
  /// entera está bloqueada (IgnorePointer + PopScope).
  void _onBack() {
    final cubit = context.read<AdminNewOrderCubit>();
    if (cubit.state.submitting) return;
    if (cubit.state.createdOrder != null) {
      context.pop();
      return;
    }
    if (cubit.state.step == AdminNewOrderStep.cobro) {
      cubit.backToComanda();
    } else {
      context.pop();
    }
  }

  /// "Crear pedido" — el cubit devuelve orden o failure y la
  /// pantalla tosteea por errorCode (mapa §042): catálogo violado,
  /// mesa stale (ya se resincronizó sola), dispatch transfer fallido
  /// o genérico. Éxito → resync de la cola y el cubit emite
  /// `createdOrder`: la VISTA de éxito (§043) reemplaza al toast+pop
  /// — el dueño puede mandar la comanda al chat de cocina antes de
  /// volver.
  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await context.read<AdminNewOrderCubit>().submit();
    // El resync de la cola NO depende del mounted: la orden igual
    // existe y la cola debe reflejarla cuando el dueño vuelva
    // (revisor-ui §042 — antes quedaba stale en ese caso borde).
    if (result.order != null) {
      locator<AdminQueueCubit>().load();
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
                              // Dos pasos + la vista de éxito (§043),
                              // una ruta — la transición queda
                              // dentro de la pantalla (§042).
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: state.createdOrder != null
                                    ? _NewOrderSuccessView(
                                        key: const ValueKey('exito'),
                                        order: state.createdOrder!,
                                      )
                                    : state.step == AdminNewOrderStep.comanda
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
                    // Oculto en loading/failed/éxito — un CTA "0 ítems"
                    // disabled bajo el spinner/error es ruido y en la
                    // vista de éxito sus dos botones ya viven centrados
                    // (revisor-ui §042 / §043).
                    BlocSelector<AdminNewOrderCubit, AdminNewOrderState, bool>(
                      selector: (state) =>
                          state.loading ||
                          state.failed ||
                          state.createdOrder != null,
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

/// Vista de éxito de la comanda (§043): reemplaza los pasos cuando
/// el POST respondió — ✓ tertiary + "Pedido #N creado" + el primario
/// "Enviar a cocina" (share sheet con UNA card PNG por ítem, armada
/// desde el BORRADOR — sus CartModifier son la forma garantizada
/// local) + el secundario "Volver a Cocina" (pop; el resync de la
/// cola ya corrió en el éxito). Decisión del dueño: el pedido se
/// reenvía al chat de cocina como imágenes — no se imprime ni se
/// dicta (v2: el formato texto wa.me quedó descartado).
class _NewOrderSuccessView extends StatefulWidget {
  const _NewOrderSuccessView({required this.order, super.key});

  /// La orden recién creada — su orderNumber encabeza el título y
  /// nutre el mensaje (servicio, pago, hora y total del servidor).
  final AdminOrder order;

  @override
  State<_NewOrderSuccessView> createState() => _NewOrderSuccessViewState();
}

class _NewOrderSuccessViewState extends State<_NewOrderSuccessView> {
  /// El render PNG + share sheet toman ~1s — durante el vuelo el
  /// CTA ignora taps (IgnorePointer) y muestra spinner onPrimary
  /// manteniendo el fill mostaza (revisor-ui §043: sin guardia,
  /// un doble-tap encolaba dos renders y dos sheets).
  bool _sharing = false;

  /// Share sheet con las cards del borrador (§043 v2) — los ítems y
  /// la nota salen del state en el toque, no del snapshot del POST.
  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final l10n = AppLocalizations.of(context)!;
      final state = context.read<AdminNewOrderCubit>().state;
      await shareKitchenItemCards(
        context,
        KitchenOrderData.fromCartItems(
          state.items,
          order: widget.order,
          tableLabel: state.selectedTable?.label,
          note: state.notes,
          l10n: l10n,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) => Padding(
        padding: EdgeInsets.only(left: c.maxWidth * kSignatureStripFraction),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tile de éxito §031b — tile + glifo, no ícono pelado:
                // tertiaryContainer 96 / radio 25% / glifo al 50% en
                // onTertiaryContainer (revisor-estetico §043: el check
                // de 44px quedaba tímido como protagonista del payoff).
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 48,
                    color: colors.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  // shortTag 'adm-N' — el MISMO identificador que la
                  // card compartida y el detalle (revisor-ui §043).
                  l10n.adminNewOrderCreatedTitle(widget.order.shortTag),
                  textAlign: TextAlign.center,
                  // Voz de título naciente — Anton mostaza pesada,
                  // la misma de Nueva orden / Revisar y cobrar.
                  style: text.headlineSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  // FilledButton global es stadium (sin filledButtonTheme)
                  // y el OutlinedButton vecino sale radius 14/52 del tema
                  // — el par apilado comparte forma local (revisor-ui
                  // §043: dos CTAs full-width con radios/alturas distintas
                  // se veían descoordinados).
                  // IgnorePointer — NO disabled: un CTA que se apaga
                  // a gris en su payoff es la regresión documentada
                  // dos veces (§035, §042; revisor-ui §043). El botón
                  // sigue mostaza con spinner onPrimary; la guardia
                  // `_sharing` corta re-entradas programáticas.
                  child: IgnorePointer(
                    ignoring: _sharing,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => unawaited(_share()),
                      icon: _sharing
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.onPrimary,
                              ),
                            )
                          : const Icon(Icons.share_rounded),
                      label: Text(l10n.adminShareWhatsApp),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: Text(l10n.adminNewOrderBackToQueue),
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
