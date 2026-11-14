import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../cubit/admin_queue_cubit.dart';
import '../cubit/admin_queue_state.dart';
import '../widgets/admin_order_card.dart';

/// Historial provisional (§036): lista plana de archivados (done
/// cerrados + cancelados) con las mismas cards en modo solo-lectura
/// — en terminal no hay acción; el straddle de la card ahora sí
/// tiene la franja detrás (lenguaje firma, decisión del dueño §036:
/// mismo patrón del detalle en todo el feature admin). Acceso:
/// ícono 🕐 del header de Cocina → /admin/history. La ubicación/
/// diseño definitivo se decide después ("historial lo resolvemos
/// después dónde va", dueño).
class AdminHistoryScreen extends StatelessWidget {
  const AdminHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          BlocBuilder<AdminQueueCubit, AdminQueueState>(
            builder: (context, state) {
              final orders = [...state.history]
                ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
              if (orders.isEmpty) {
                final text = Theme.of(context).textTheme;
                return LayoutBuilder(
                  builder: (context, c) => ListView(
                    children: [
                      const _HistoryTitle(),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: c.maxHeight - 80,
                        ),
                        child: Padding(
                          // Zona negra (§034c).
                          padding: EdgeInsets.only(
                            left: c.maxWidth * kSignatureStripFraction,
                            right: 32,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 44,
                                  color: colors.primary.withValues(alpha: 0.85),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.adminQueueEmptyHistoryTitle,
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.adminQueueEmptyHistoryBody,
                                  textAlign: TextAlign.center,
                                  style: text.bodyMedium?.copyWith(
                                    color: colors.onSurface.withValues(
                                      alpha: 0.6,
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
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const _HistoryTitle(),
                  for (final order in orders)
                    // Lista plana sin carriles — aquí el chip de
                    // estado SÍ aporta (Cancelado vs. lo que venga
                    // cerrado después).
                    AdminOrderCard(
                      order: order,
                      busy: false,
                      showStatusChip: true,
                    ),
                ],
              );
            },
          ),
          // Flecha sobre la franja — onPrimary negro sobre mostaza
          // (misma geometría del detalle §035).
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
  }
}

/// Título "Historial" — mismo patrón scrolling_title que el
/// detalle: primer hijo del ListView en la zona negra (0.602 a la
/// derecha) en mostaza pesada.
class _HistoryTitle extends StatelessWidget {
  const _HistoryTitle();

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
              l10n.adminHistoryTitle,
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
