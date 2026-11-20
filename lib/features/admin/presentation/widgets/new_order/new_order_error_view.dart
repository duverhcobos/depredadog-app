import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../home/presentation/widgets/signature_strip.dart';

/// Error de la carga inicial de la comanda (§042 — misma familia
/// `_DayCloseError`/`_QueueError`): ícono cloud_off + mensaje +
/// Reintentar, acotado a la zona negra; el load() se re-pide en el
/// toque.
class NewOrderErrorView extends StatelessWidget {
  const NewOrderErrorView({required this.onRetry, super.key});

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
                l10n.adminNewOrderLoadError,
                textAlign: TextAlign.center,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(l10n.catalogRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
