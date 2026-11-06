import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/checkout_cubit.dart';
import '../cubit/checkout_state.dart';
import 'delivery_address_block.dart';

/// Cuerpo de la sección "Tipo de pedido" (§022): debajo del toggle,
/// cambia según el modo — pickup muestra el local; domicilio muestra
/// las direcciones + el form de nueva.
class OrderTypeBody extends StatelessWidget {
  const OrderTypeBody({super.key});

  @override
  Widget build(BuildContext context) {
    final orderType = context.watch<CheckoutCubit>().state.orderType;
    // Misma física del feature (form de dirección / campo Nequi):
    // 180ms easeOutCubic — antes el cuerpo cambiaba en corte duro.
    // AnimatedSize por fuera para que el alto acompañe la
    // transición, no salte (revisor-ui).
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: orderType == CheckoutOrderType.pickup
            ? const _PickupInfo(key: ValueKey('pickup'))
            : const DeliveryAddressBlock(key: ValueKey('delivery')),
      ),
    );
  }
}

/// "Lo recoges en" + dirección del local + aviso (§022).
class _PickupInfo extends StatelessWidget {
  const _PickupInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final store = context.read<CheckoutCubit>().state.store;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.storefront_rounded, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.checkoutPickupAtLabel,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                Text(
                  '${store.name} — ${store.address}',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.checkoutPickupNotice,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
