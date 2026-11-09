import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../cubit/checkout_cubit.dart';

/// Fila del pin de Google Maps del pedido (§022d): botón outlined
/// "Adjuntar ubicación de Google" → estado adjunto (check primary +
/// link + ✕ quitar). Order-level: el punto exacto aplica a la
/// dirección que esté marcada — nueva o guardada (mock: link fijo).
class DeliveryLocationPin extends StatelessWidget {
  const DeliveryLocationPin({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.watch<CheckoutCubit>();
    final link = cubit.state.deliveryLocationLink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: link == null
          ? Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: cubit.attachDeliveryLocation,
                icon: const Icon(Icons.pin_drop_rounded, size: 18),
                label: Text(l10n.checkoutAttachLocation),
              ),
            )
          : Semantics(
              label: '${l10n.checkoutLocationAttached}: $link',
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.checkoutLocationAttached,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          link,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: l10n.checkoutRemoveLocation,
                    onPressed: cubit.removeDeliveryLocation,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
    );
  }
}
