import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/utils/format_cop.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../domain/entities/admin_day_close.dart';
import '../cubit/admin_queue_cubit.dart';
import '../cubit/admin_queue_state.dart';

/// Cierre de caja del día (§036 presentación; §041 integración
/// real — GET/POST /admin/day-close): preview del resumen
/// (entregados por archivar, total, por método, cancelados del
/// periodo) → "Confirmar cierre" ejecuta → estado de éxito con
/// check + el resumen cerrado + "Listo" que regresa.
/// El cierre vacío está permitido (decisión del dueño) — con cero
/// entregados la pantalla muestra el resumen en ceros con su nota.
/// Lenguaje: firma de marca (franja + flecha onPrimary + título
/// naciente) — mismo patrón del detalle §035, un solo idioma visual
/// en todo el feature admin (decisión del dueño §036).
class AdminDayCloseScreen extends StatefulWidget {
  const AdminDayCloseScreen({super.key});

  @override
  State<AdminDayCloseScreen> createState() => _AdminDayCloseScreenState();
}

class _AdminDayCloseScreenState extends State<AdminDayCloseScreen> {
  /// Snapshot del resultado — tras cerrar, el resumen queda fijo
  /// aunque el cubit archive los done y vacíe el carril Entregado.
  AdminDayClose? _result;

  @override
  void initState() {
    super.initState();
    // Preview al entrar — GET /admin/day-close real (§041).
    context.read<AdminQueueCubit>().loadDayClosePreview();
  }

  Future<void> _confirmClose() async {
    final result = await context.read<AdminQueueCubit>().closeDay();
    if (!mounted) return;
    if (result == null) {
      AppToast.error(
        context,
        AppLocalizations.of(context)!.adminToastDayCloseFailed,
      );
      return;
    }
    AppToast.success(
      context,
      AppLocalizations.of(context)!
          .adminToastDayClosed(formatCop(result.totalAmount)),
    );
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return BlocBuilder<AdminQueueCubit, AdminQueueState>(
      builder: (context, state) {
        final summary = _result ?? state.dayClose;
        return Scaffold(
          body: Stack(
            children: [
              const SignatureStrip(fraction: kSignatureStripFraction),
              Column(
                children: [
                  Expanded(
                    child: summary == null
                        ? LayoutBuilder(
                            builder: (context, c) => state.dayCloseFailed
                                ? _DayCloseError(
                                    onRetry: () => context
                                        .read<AdminQueueCubit>()
                                        .loadDayClosePreview(),
                                  )
                                : Padding(
                                    padding: EdgeInsets.only(
                                      left: c.maxWidth *
                                          kSignatureStripFraction,
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: colors.primary,
                                      ),
                                    ),
                                  ),
                          )
                        : LayoutBuilder(
                            builder: (context, c) => ListView(
                              padding: const EdgeInsets.only(bottom: 24),
                              children: [
                                const _DayCloseTitle(),
                                // Todo el contenido acotado a la
                                // zona negra — nada pinta sobre la
                                // franja (regla §034c).
                                Padding(
                                  padding: EdgeInsets.only(
                                    left:
                                        c.maxWidth * kSignatureStripFraction +
                                        16,
                                    right: 16,
                                    top: 8,
                                  ),
                                  child: Column(
                                    children: [
                                      if (_result != null) ...[
                                        const SizedBox(height: 8),
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 44,
                                          color: colors.tertiary,
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      _TotalHero(amount: summary.totalAmount),
                                      const SizedBox(height: 16),
                                      _SummaryRows(summary: summary),
                                      if (summary.cancelledCount > 0) ...[
                                        const SizedBox(height: 8),
                                        _CancelledRow(summary: summary),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  // Footer fijo opaco full-width (patrón detalle
                  // §035 / cart): sin el SizedBox infinity el
                  // DecoratedBox shrink-wrappeaba al botón y la
                  // franja sangraba por debajo (revisor-ui §036).
                  DecoratedBox(
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
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: _result == null
                              ? IgnorePointer(
                                  ignoring: state.dayCloseBusy,
                                  child: FilledButton(
                                    // Sin resumen visible NO se
                                    // cierra a ciegas: disabled
                                    // mientras carga o tras el
                                    // error del preview (revisor
                                    // §041).
                                    onPressed:
                                        summary == null ? null : _confirmClose,
                                    child: state.dayCloseBusy
                                        ? SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: colors.onPrimary,
                                            ),
                                          )
                                        : Text(l10n.adminDayCloseConfirm),
                                  ),
                                )
                              : FilledButton(
                                  // Sólido — es el ÚNICO gesto del
                                  // estado de éxito (revisor-estetico).
                                  onPressed: () => context.pop(),
                                  child: Text(l10n.adminDayCloseDone),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Flecha sobre la franja — onPrimary negro sobre
              // mostaza (misma geometría del detalle §035).
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

/// Error del preview (§041 — misma familia `_QueueError` de la
/// cola): ícono cloud_off + mensaje + Reintentar, acotado a la zona
/// negra como el spinner — el GET /admin/day-close se re-pide en el
/// toque. Sin el flag dayCloseFailed la pantalla quedaba en spinner
/// eterno.
class _DayCloseError extends StatelessWidget {
  const _DayCloseError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) => Padding(
        padding: EdgeInsets.only(left: c.maxWidth * kSignatureStripFraction),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.adminDayCloseLoadError,
                textAlign: TextAlign.center,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(l10n.ordersRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Título "Cierre de caja" — mismo patrón scrolling_title que el
/// detalle: primer hijo del ListView en la zona negra (0.602 a la
/// derecha) en mostaza pesada.
class _DayCloseTitle extends StatelessWidget {
  const _DayCloseTitle();

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
              l10n.adminDayCloseTitle,
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

/// Hero del total — el número que el dueño quiere ver primero.
class _TotalHero extends StatelessWidget {
  const _TotalHero({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          l10n.adminDayCloseTotal,
          style: text.labelLarge?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatCop(amount),
          style: text.displaySmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

/// Filas del resumen: "N pedidos entregados" + desglose por método
/// ("Efectivo — 5 · $120.000"). Mismo formato money del proyecto
/// (formatCop). Con cero entregados aparece la nota del cierre
/// vacío — el registro queda como bitácora (decisión del dueño).
class _SummaryRows extends StatelessWidget {
  const _SummaryRows({required this.summary});

  final AdminDayClose summary;

  String _methodLabel(AppLocalizations l10n, String method) => switch (method) {
    'cash' => l10n.adminPaymentCash,
    'transfer' => l10n.adminPaymentTransfer,
    'nequi' => l10n.adminPaymentNequi,
    _ => method,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        _SummaryRow(label: l10n.adminDayCloseOrders(summary.orderCount)),
        for (final m in summary.byMethod)
          _SummaryRow(
            label: _methodLabel(l10n, m.method),
            value: '${m.count} · ${formatCop(m.amount)}',
          ),
        if (summary.orderCount == 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l10n.adminDayCloseEmpty,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
      ],
    );
  }
}

/// Fila label → valor del resumen del cierre.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: text.titleSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

/// Contexto del dueño: "N cancelados · $X" — no suma al total, es
/// la bitácora de lo que no se vendió en el periodo.
class _CancelledRow extends StatelessWidget {
  const _CancelledRow({required this.summary});

  final AdminDayClose summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = colors.onSurface.withValues(alpha: 0.6);
    return Column(
      children: [
        Divider(color: colors.outlineVariant, height: 24),
        Row(
          children: [
            Icon(Icons.cancel_outlined, size: 15, color: muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.adminDayCloseCancelled(
                  summary.cancelledCount,
                  formatCop(summary.cancelledAmount),
                ),
                style: text.bodySmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
