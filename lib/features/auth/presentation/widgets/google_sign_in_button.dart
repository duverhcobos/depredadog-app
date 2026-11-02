import 'package:flutter/material.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';

/// Botón de Google sign-in (propuesta 014): `onPressed` recibe el callback
/// del cubit; null = sin integración configurada todavía — el botón queda
/// en su comportamiento provisional (toast "Disponible próximamente").
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, this.onPressed});

  /// Acción del flujo Google (login o register — cada pantalla la cablea
  /// a su cubit).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed:
            onPressed ?? () => AppToast.success(context, l10n.comingSoon),
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
