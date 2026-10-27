import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// PROVISIONAL: destino de /home hasta que la feature home exista.
/// Hoy es inalcanzable (AuthGuard exige sesión y isAuthenticated=false).
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Text('${l10n.appName} — ${l10n.comingSoon}'),
      ),
    );
  }
}
