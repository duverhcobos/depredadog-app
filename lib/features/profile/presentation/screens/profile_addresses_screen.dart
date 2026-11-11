import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../cubit/profile_addresses_cubit.dart';
import '../cubit/profile_addresses_state.dart';
import '../widgets/profile_address_tile.dart';

/// "Mis direcciones" (§030 — hija de la rama profile, conserva shell
/// + nav igual que /orders/:id): gestión COMPLETA sobre mock — badge
/// "Predeterminada", marcar otra como default (PATCH {isDefault:true}
/// en fase 2), eliminar con diálogo y crear/editar en
/// /profile/addresses/new|edit. Vacío = ícono + copy + CTA "Nueva
/// dirección" (misma familia que el vacío del carrito — la creación
/// debe seguir alcanzable).
class ProfileAddressesScreen extends StatelessWidget {
  const ProfileAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          BlocBuilder<ProfileAddressesCubit, ProfileAddressesState>(
            builder: (context, state) {
              if (state.addresses.isEmpty) {
                // Vacío: no hay scroll — Column fija + centrado real
                // dentro de la zona NEGRA (revisor-ui §020/§027).
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _AddressesTitle(),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => Padding(
                          padding: EdgeInsets.only(
                            left: c.maxWidth * kSignatureStripFraction,
                          ),
                          child: const Center(child: _AddressesEmpty()),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const _AddressesTitle(),
                  for (final address in state.addresses)
                    ProfileAddressTile(address: address),
                  // CTA al pie — ancho completo dentro de la misma
                  // geometría straddle que las cards (misma familia
                  // que "Agregar" del carrito).
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
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: () => context.push(
                              AuthGuard.profileAddressNewRoute,
                            ),
                            icon: const Icon(
                              Icons.add_location_alt_outlined,
                              size: 18,
                            ),
                            label: Text(l10n.addressesNewCta),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          // Flecha back sobre la franja — misma posición que
          // cart/checkout/detalle (hija pusheada, no tab).
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
    );
  }
}

/// Título "Mis direcciones" naciendo de la franja — patrón
/// scrolling_title (PRIMER hijo del ListView; en vacío vive fijo en
/// la Column porque no hay scroll).
class _AddressesTitle extends StatelessWidget {
  const _AddressesTitle();

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
              l10n.addressesTitle,
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

/// Vista vacía (§030): ícono + copy + CTA de creación — misma
/// composición del carrito/pedidos vacío (ícono + título + sub +
/// FilledButton.tonalIcon).
class _AddressesEmpty extends StatelessWidget {
  const _AddressesEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 48,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.addressesEmpty,
            textAlign: TextAlign.center,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.addressesEmptyHint,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => context.push(AuthGuard.profileAddressNewRoute),
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: Text(l10n.addressesNewCta),
          ),
        ],
      ),
    );
  }
}
