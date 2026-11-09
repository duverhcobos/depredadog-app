import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../cubit/checkout_cubit.dart';

/// Placeholder de la zona de direcciones mientras corre la carga
/// inicial (§025 — spinner chico; el CTA del footer también espera).
class AddressesLoading extends StatelessWidget {
  const AddressesLoading({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Center(
      child: SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}

/// Aviso inline cuando GET /addresses falla (§025): ícono + texto +
/// retry — "Nueva ubicación" queda como única opción del domicilio (el
/// pickup nunca se bloquea).
class AddressesErrorNotice extends StatelessWidget {
  const AddressesErrorNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 4),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.checkoutAddressesError,
              style: text.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: context.read<CheckoutCubit>().loadCheckoutData,
            child: Text(l10n.checkoutRetry),
          ),
        ],
      ),
    );
  }
}
