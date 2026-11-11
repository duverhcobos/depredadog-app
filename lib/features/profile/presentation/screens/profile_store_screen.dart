import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/store_status_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../../../orders/presentation/utils/format_phone.dart';
import '../../../store/domain/entities/store_info.dart';
import '../../../store/domain/entities/store_open_state.dart';
import '../../../store/presentation/cubit/store_status_cubit.dart';
import '../cubit/profile_store_cubit.dart';
import '../cubit/profile_store_state.dart';

/// "El local" (§030.1 — /profile/store, hija de la rama profile):
/// card con el nombre del negocio + chip abierto/cerrado REAL
/// (`StoreStatusCubit` del shell — el mismo del header; `unknown`
/// oculta el chip igual que allá: mejor no mostrar que mentir), las 7
/// filas del horario semanal (hoy resaltada en mostaza) y las filas de
/// dirección y teléfono (copiable, patrón Clipboard+toast del diálogo
/// de Soporte). Los datos vienen del ProfileStoreCubit (mock fase 1 —
/// StoreInfo ya espeja StoreConfigResponseDto).
class ProfileStoreScreen extends StatelessWidget {
  const ProfileStoreScreen({super.key});

  /// 'HH:MM' del backend → 12h es-CO ("17:00" → "5:00 p. m.") —
  /// el mismo dialecto de hora que usan los pedidos ("12:40 p. m."),
  /// no el crudo 24h del DTO (revisor-ui §030.1).
  static String _formatHour(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first) ?? 0;
    final m = parts.length > 1 ? parts[1] : '00';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final ampm = h < 12 ? 'a. m.' : 'p. m.';
    return '$h12:$m $ampm';
  }

  /// Nombre del día por `dayOfWeek` del backend (convención JS:
  /// 0 = domingo … 6 = sábado).
  static String _dayName(AppLocalizations l10n, int dayOfWeek) =>
      switch (dayOfWeek) {
        0 => l10n.storeDaySunday,
        1 => l10n.storeDayMonday,
        2 => l10n.storeDayTuesday,
        3 => l10n.storeDayWednesday,
        4 => l10n.storeDayThursday,
        5 => l10n.storeDayFriday,
        6 => l10n.storeDaySaturday,
        _ => '',
      };

  /// Copia el teléfono del local — mismo patrón Clipboard + toast del
  /// diálogo de Soporte (§030).
  Future<void> _copyPhone(BuildContext context, String phone) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: phone));
    if (!context.mounted) return;
    AppToast.success(context, l10n.profileCopiedNumberToast);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          BlocBuilder<ProfileStoreCubit, ProfileStoreState>(
            builder: (context, state) {
              final store = state.store;
              // Hoy en la convención del backend: Date.getDay() —
              // Dart weekday 1-7 (lun-dom) → 0-6 (dom-sáb).
              final today = DateTime.now().weekday % 7;
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const _StoreTitle(),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: LayoutBuilder(
                      builder: (context, c) => Padding(
                        padding: EdgeInsets.only(
                          left:
                              c.maxWidth *
                              kSignatureStripFraction *
                              kCardStripInset,
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
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StoreHeader(name: store.name),
                                Divider(
                                  height: 20,
                                  thickness: 1,
                                  color: colors.outlineVariant.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                Text(
                                  l10n.profileStoreHoursLabel,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                for (final day in store.weeklyHours)
                                  _DayHoursRow(
                                    day: day,
                                    dayName: _dayName(l10n, day.dayOfWeek),
                                    isToday: day.dayOfWeek == today,
                                  ),
                                Divider(
                                  height: 20,
                                  thickness: 1,
                                  color: colors.outlineVariant.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                if (store.address != null)
                                  _InfoRow(
                                    icon: Icons.place_outlined,
                                    text: store.address!,
                                  ),
                                if (store.phone != null)
                                  _InfoRow(
                                    icon: Icons.phone_outlined,
                                    text: formatPhone(store.phone!),
                                    copyTooltip: l10n.profileCopyNumber,
                                    onCopy: () =>
                                        _copyPhone(context, store.phone!),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          // Flecha back sobre la franja — misma posición de las demás
          // hijas del perfil.
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

/// Cabecera de la card: nombre del local + chip de estado REAL —
/// `BlocBuilder<StoreStatusCubit, StoreOpenState>` igual que el header
/// del shell (unknown → oculto).
class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        BlocBuilder<StoreStatusCubit, StoreOpenState>(
          builder: (context, status) => status == StoreOpenState.unknown
              ? const SizedBox.shrink()
              : StoreStatusChip(isOpen: status == StoreOpenState.open),
        ),
      ],
    );
  }
}

/// Una fila del horario semanal: día a la izquierda, rango 'HH:MM –
/// HH:MM' o "Cerrado" a la derecha. La fila de HOY va resaltada en
/// mostaza w700 — la única señal de "dónde estamos" en la semana.
class _DayHoursRow extends StatelessWidget {
  const _DayHoursRow({
    required this.day,
    required this.dayName,
    required this.isToday,
  });

  final StoreDayHours day;
  final String dayName;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final closed = day.isClosed && !isToday;
    final style = text.bodyMedium?.copyWith(
      color: isToday
          ? colors.primary
          : closed
          ? colors.onSurface.withValues(alpha: 0.55)
          : null,
      fontWeight: isToday ? FontWeight.w700 : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(dayName, style: style)),
          Text(
            day.isClosed
                ? l10n.homeStoreClosed
                : '${ProfileStoreScreen._formatHour(day.opensAt)} – '
                      '${ProfileStoreScreen._formatHour(day.closesAt)}',
            style: style,
          ),
        ],
      ),
    );
  }
}

/// Fila informativa (dirección / teléfono): ícono + texto; el teléfono
/// además lleva su botón copiar (Clipboard + toast — patrón §030).
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    this.copyTooltip,
    this.onCopy,
  });

  final IconData icon;
  final String text;
  final String? copyTooltip;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: textTheme.bodyMedium)),
          if (onCopy != null)
            IconButton(
              tooltip: copyTooltip,
              onPressed: onCopy,
              icon: Icon(Icons.copy_rounded, size: 20, color: colors.primary),
            ),
        ],
      ),
    );
  }
}

/// Título "El local" naciendo de la franja — patrón scrolling_title
/// (PRIMER hijo del ListView).
class _StoreTitle extends StatelessWidget {
  const _StoreTitle();

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
              l10n.profileStoreTitle,
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
