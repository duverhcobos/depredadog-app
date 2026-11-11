import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../checkout/domain/entities/saved_address.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../cubit/profile_addresses_cubit.dart';

/// Fila de una dirección guardada (§030): card straddle con ícono por
/// tipo + label + badge "Predeterminada" (solo `isDefault`) + detalle
/// (referencia · sector). Tap → edición (SavedAddress viaja como
/// extra, patrón cart/edit). El menú ⋮ ofrece "Marcar predeterminada"
/// (deshabilitada si ya lo es — PATCH {isDefault:true} en fase 2) y
/// "Eliminar" con diálogo de confirmación real.
class ProfileAddressTile extends StatelessWidget {
  const ProfileAddressTile({required this.address, super.key});

  final SavedAddress address;

  IconData _iconFor(SavedAddressType type) => switch (type) {
    SavedAddressType.home => Icons.home_outlined,
    SavedAddressType.work => Icons.work_outline,
    SavedAddressType.other => Icons.place_outlined,
  };

  /// Confirmación de borrado — patrón `showOrderCancelDialog`
  /// (cancelar / confirmar rojo). El DELETE real llega en fase 2;
  /// hoy es el borrado optimista local del cubit.
  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.addressDeleteConfirmTitle),
        content: Text(l10n.addressDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profileCancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: Text(l10n.addressDeleteConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.read<ProfileAddressesCubit>().delete(address.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
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
            child: InkWell(
              onTap: () => context.push(
                AuthGuard.profileAddressEditRoute,
                extra: address,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                child: Row(
                  children: [
                    Icon(
                      _iconFor(address.type),
                      size: 20,
                      color: colors.onSurface.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  address.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (address.isDefault) ...[
                                const SizedBox(width: 8),
                                // Badge "Predeterminada" — una sola por
                                // contrato del backend (índice parcial).
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    l10n.addressDefaultBadge,
                                    style: text.labelSmall?.copyWith(
                                      color: colors.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            address.detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: colors.onSurface.withValues(alpha: 0.65),
                      ),
                      onSelected: (value) {
                        if (value == 'default') {
                          context.read<ProfileAddressesCubit>().markDefault(
                            address.id,
                          );
                        } else if (value == 'delete') {
                          _confirmDelete(context);
                        }
                      },
                      itemBuilder: (context) => [
                        // Ya es default → la opción queda visible pero
                        // gris/inerte (feedback honesto, no oculta).
                        PopupMenuItem(
                          value: 'default',
                          enabled: !address.isDefault,
                          child: Row(
                            children: [
                              const Icon(Icons.star_outline_rounded, size: 18),
                              const SizedBox(width: 8),
                              // Expanded — el Row del item tiene ancho
                              // finito (menú 256px): sin él el texto
                              // largo desborda (RenderFlex).
                              Expanded(child: Text(l10n.addressMakeDefault)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: colors.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.addressDelete,
                                  style: TextStyle(color: colors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
