import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Estados de carga/error compartidos por las pantallas de catálogo
/// (§019). Los estados CON datos visibles nunca caen acá — el refresh
/// silencioso no tumba el contenido.
class CatalogLoadingView extends StatelessWidget {
  const CatalogLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Error sin caché: ícono + título + subtítulo + retry. El usuario ve
/// esto solo cuando la PRIMERA carga falla (sin datos que mostrar).
class CatalogErrorView extends StatelessWidget {
  const CatalogErrorView({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.catalogLoadErrorTitle,
              textAlign: TextAlign.center,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.catalogLoadErrorSubtitle,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.catalogRetry),
            ),
          ],
        ),
      ),
    );
  }
}
