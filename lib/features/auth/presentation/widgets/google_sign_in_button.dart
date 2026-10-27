import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// PROVISIONAL: botón de Google sin endpoint — muestra un aviso hasta que
/// /auth/google se integre (client IDs pendientes — ver propuesta de
/// integración correspondiente).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.comingSoon)));
        },
        // Alto/radius vienen del outlinedButtonTheme del tema.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/google_g.png', height: 20, width: 20),
            const SizedBox(width: 12),
            Text(l10n.loginGoogleButton),
          ],
        ),
      ),
    );
  }
}
