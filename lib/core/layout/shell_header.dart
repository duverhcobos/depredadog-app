import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/presentation/cubit/cart_cubit.dart';
import '../../features/store/domain/entities/store_open_state.dart';
import '../../features/store/presentation/cubit/store_status_cubit.dart';
import '../../l10n/app_localizations.dart';
import '../routes/auth_guard.dart';
import '../widgets/app_toast.dart';
import '../widgets/store_status_chip.dart';

/// Cabecera fija del shell autenticado (§016): imagotipo a la izquierda,
/// acciones a la derecha. La campana sigue PROVISIONAL (toast
/// "Disponible próximamente" hasta el módulo notificaciones); el
/// carrito ya es real (§020) — badge = unidades del CartCubit y
/// navega a /home/cart.
class ShellHeader extends StatelessWidget {
  const ShellHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Image.asset(
              // Variante HORIZONTAL del brand kit (isotipo + wordmark) —
              // el imagotipo vertical deja el tagline ilegible en banda.
              'assets/images/imagotipo_horizontal_blanco.png',
              height: 40,
              fit: BoxFit.contain,
              semanticLabel: l10n.appName,
            ),
            const Spacer(),
            // Estado del local REAL (§029 — StoreStatusCubit del
            // shell; mata el mock §017). `unknown` → chip oculto:
            // mejor no mostrar que mentir Abierto/Cerrado.
            BlocBuilder<StoreStatusCubit, StoreOpenState>(
              builder: (context, status) => status == StoreOpenState.unknown
                  ? const SizedBox.shrink()
                  : StoreStatusChip(isOpen: status == StoreOpenState.open),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: l10n.shellNotificationsTooltip,
              onPressed: () => AppToast.info(context, l10n.comingSoon),
            ),
            _buildCartButton(context, l10n, colors),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  /// Carrito: PUSH a /home/cart (§020) — preserva el stack: desde el
  /// detalle con personalización en curso, volver regresa al detalle
  /// intacto (go() lo destruía, revisor-ui §020). Badge = unidades
  /// reales del CartCubit — invisible en 0, cap visual "99+".
  Widget _buildCartButton(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colors,
  ) {
    final count = context.select((CartCubit c) => c.state.itemCount);
    // Dentro del carrito el ícono se deshabilita — pushear /home/cart
    // sobre sí misma apilaba la misma pantalla y el back "mentía"
    // (revisor-ui §020, re-crítica).
    final isOnCart = GoRouterState.of(context).uri.path == AuthGuard.cartRoute;
    return Semantics(
      // Label combinado: "Carrito" + count sueltos competían como
      // dos nodos (revisor-ui §020).
      label: count > 0 ? l10n.cartBadgeA11y(count) : l10n.shellCartTooltip,
      button: true,
      enabled: !isOnCart,
      child: IconButton(
        tooltip: l10n.shellCartTooltip,
        onPressed: isOnCart ? null : () => context.push(AuthGuard.cartRoute),
        icon: Badge(
          isLabelVisible: count > 0,
          label: ExcludeSemantics(
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
          backgroundColor: colors.primary,
          textColor: colors.onPrimary,
          child: Icon(Icons.shopping_cart_outlined, color: colors.onSurface),
        ),
      ),
    );
  }
}
