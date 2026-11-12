import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/di/setup_di.dart';
import '../../../../core/routes/auth_guard.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/auth_required_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/presentation/widgets/signature_strip.dart';
import '../cubit/profile_addresses_cubit.dart';
import '../cubit/profile_addresses_state.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/profile_state.dart';
import '../widgets/logout_confirm_dialog.dart';
import '../widgets/profile_identity_card.dart';
import '../widgets/profile_loyalty_card.dart';
import '../widgets/profile_menu_row.dart';
import '../widgets/profile_section_label.dart';
import '../widgets/profile_support_dialog.dart';

/// Tab Perfil (§030 + §030.1, solo presentación — mocks del cubit,
/// patrón §023): franja firma + título naciente dentro del scroll +
/// card de identidad (avatar iniciales, nombre, email, celular) +
/// loyalty card (puntos + código de referido copiable + referidos) +
/// menú en secciones: "Mi cuenta" (Mis datos → /profile/data, Mis
/// direcciones → /profile/addresses, Cambiar contraseña →
/// /profile/password) y "El negocio" (El local → /profile/store,
/// Soporte → diálogo WhatsApp) + la destructiva "Cerrar sesión"
/// como ÚLTIMO ÍTEM del scroll (decisión usuario §030.1 — era
/// anclada; con el menú completo pertenece al final de la lista).
/// Es tab — no lleva flecha back.
///
/// §031 — el tab es PÚBLICO: el invitado ve la misma info del muro
/// como CARD straddle dentro del scroll (el tab sí muestra contenido
/// real debajo: la sección "El negocio" con El local y Soporte, que
/// son info pública). Sin identidad, loyalty, "Mi cuenta" ni logout.
/// El contenido se decide por sesión EN VIVO vía ListenableBuilder y
/// los cubits de datos de cliente solo se instancian en la rama
/// autenticada (el invitado no dispara cubits de cliente).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = locator<AuthSession>();
    return Scaffold(
      body: Stack(
        children: [
          const SignatureStrip(fraction: kSignatureStripFraction),
          ListenableBuilder(
            listenable: session,
            builder: (context, _) => session.isAuthenticated
                ? const _AuthedProfile()
                : const _GuestProfile(),
          ),
        ],
      ),
    );
  }
}

/// Rama con sesión del tab: el contenido de §030/§030.1 intacto,
/// con los singletons ProfileCubit/ProfileAddressesCubit instalados
/// acá — el invitado nunca los resuelve y el swap muro→contenido los
/// monta en vivo (la página puede quedar viva debajo del login).
class _AuthedProfile extends StatelessWidget {
  const _AuthedProfile();

  /// Diálogo real (estilo order_cancel_dialog) → acción mock de fase
  /// 1 (ProfileCubit.logout es stub; la limpieza de sesión + go
  /// /login llegan con POST /auth/logout en integración). El toast
  /// cierra el loop — una acción destructiva confirmada nunca muere
  /// en silencio (revisor-ui).
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showLogoutConfirmDialog(context);
    if (!confirmed || !context.mounted) return;
    await context.read<ProfileCubit>().logout();
    if (!context.mounted) return;
    AppToast.info(
      context,
      AppLocalizations.of(context)!.profileLogoutSoonToast,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MultiBlocProvider(
      providers: [
        // §030 — singleton compartido con las hijas via
        // BlocProvider.value (patrón OrdersCubit §027): las páginas
        // hijas en go_router son HERMANAS de la madre en el
        // Navigator, no heredan su provider.
        BlocProvider.value(value: locator<ProfileCubit>()),
        // El subtítulo "N guardadas" lee esta MISMA instancia —
        // nunca diverge de la lista.
        BlocProvider.value(value: locator<ProfileAddressesCubit>()),
      ],
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          final user = state.user;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const _ProfileTitle(),
              if (user != null) ProfileIdentityCard(user: user),
              if (state.referralCode != null || state.loyaltyPoints > 0)
                ProfileLoyaltyCard(
                  code: state.referralCode,
                  points: state.loyaltyPoints,
                  referredCount: state.referredCount,
                ),
              const SizedBox(height: 16),
              // Sección "Mi cuenta" — lo que el cliente edita
              // de sí mismo (§030.1).
              ProfileSectionLabel(label: l10n.profileSectionAccount),
              ProfileMenuRow(
                icon: Icons.badge_outlined,
                title: l10n.profileDataRow,
                onTap: () => context.push(AuthGuard.profileDataRoute),
              ),
              // Conteo desde el cubit de la lista — si el
              // usuario crea/borra en la sesión, el número
              // siempre coincide con lo que la lista muestra.
              BlocBuilder<ProfileAddressesCubit, ProfileAddressesState>(
                builder: (context, addrState) => ProfileMenuRow(
                  icon: Icons.location_on_outlined,
                  title: l10n.profileAddressesRow,
                  subtitle: l10n.profileAddressesCount(
                    addrState.addresses.length,
                  ),
                  onTap: () => context.push(AuthGuard.profileAddressesRoute),
                ),
              ),
              ProfileMenuRow(
                icon: Icons.lock_outline,
                title: l10n.profilePasswordRow,
                onTap: () => context.push(AuthGuard.profilePasswordRoute),
              ),
              const SizedBox(height: 16),
              // Sección "El negocio" — info del local y ayuda.
              ProfileSectionLabel(label: l10n.profileSectionBusiness),
              ProfileMenuRow(
                icon: Icons.storefront_outlined,
                title: l10n.profileStoreRow,
                onTap: () => context.push(AuthGuard.profileStoreRoute),
              ),
              ProfileMenuRow(
                icon: Icons.support_agent_outlined,
                title: l10n.profileSupportRow,
                opensDialog: true,
                onTap: () => showProfileSupportDialog(context),
              ),
              const SizedBox(height: 24),
              // Destructiva como último ítem del scroll —
              // peligro al final de la lista (decisión
              // usuario §030.1).
              ProfileMenuRow(
                icon: Icons.logout_outlined,
                title: l10n.profileLogoutRow,
                destructive: true,
                onTap: () => _confirmLogout(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Vista del invitado (§031 — decisión del usuario): el muro como
/// CARD straddle dentro del scroll (misma info del muro compartido —
/// ícono + título + CTAs — no pantalla de estado, porque el tab sí
/// muestra contenido real debajo) + la sección "El negocio" con las
/// mismas filas de hoy (El local → /profile/store es ruta pública;
/// Soporte → diálogo). Sin identidad, loyalty, "Mi cuenta" ni logout.
class _GuestProfile extends StatelessWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const _ProfileTitle(),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: LayoutBuilder(
            // Geometría straddle de la casa: la card nace dentro de
            // la franja y desborda al negro (misma cuna que las
            // ProfileMenuRow de abajo).
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: AuthRequiredView(
                    // Misma variante rounded que el ícono del tab
                    // Perfil en la nav (revisor-ui §031).
                    icon: Icons.person_outline_rounded,
                    iconSize: 64,
                    title: l10n.guestProfileTitle,
                    message: l10n.guestProfileBody,
                    fromRoute: AuthGuard.profileRoute,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // "El negocio" — horarios/abierto/dirección del local y la
        // ayuda son info pública que le sirve a cualquiera (§031).
        ProfileSectionLabel(label: l10n.profileSectionBusiness),
        ProfileMenuRow(
          icon: Icons.storefront_outlined,
          title: l10n.profileStoreRow,
          onTap: () => context.push(AuthGuard.profileStoreRoute),
        ),
        ProfileMenuRow(
          icon: Icons.support_agent_outlined,
          title: l10n.profileSupportRow,
          opensDialog: true,
          onTap: () => showProfileSupportDialog(context),
        ),
      ],
    );
  }
}

/// Título "Perfil" naciendo de la franja — patrón scrolling_title
/// (FractionallySizedBox en la zona negra, PRIMER hijo del ListView:
/// sale al bajar y reaparece al subir — igual que orders/cart).
class _ProfileTitle extends StatelessWidget {
  const _ProfileTitle();

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
              l10n.profileTitle,
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
