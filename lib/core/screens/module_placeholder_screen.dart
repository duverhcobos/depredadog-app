import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Destino provisional de una branch del shell mientras su módulo real
/// no existe (§016). Sigue el patrón de pantalla de estado de
/// ui-design-standard: icono decorativo 80px primary + nombre del módulo
/// + "Disponible próximamente".
class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({
    required this.icon,
    required this.moduleLabel,
    super.key,
  });

  final IconData icon;
  final String moduleLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 80, color: colors.primary),
            const SizedBox(height: 16),
            Text(moduleLabel, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.comingSoon,
              style: text.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
