import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Encabezado de marca del login: imagotipo vertical Depredadog
/// (positiva en tema claro, negativa/rellenos blancos en oscuro)
/// + headline + subtítulo.
class LoginBrandHeader extends StatelessWidget {
  const LoginBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        Image.asset(
          isDark
              ? 'assets/images/imagotipo_depredadog_dark.png'
              : 'assets/images/imagotipo_depredadog.png',
          height: 148,
          fit: BoxFit.contain,
          semanticLabel: l10n.appName,
        ),
        const SizedBox(height: 24),
        Text(
          l10n.loginHeadline,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.loginSubtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
