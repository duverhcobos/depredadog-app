import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Footer persistente de los wizards de auth (propuesta 009):
/// "¿Ya tienes cuenta? Inicia sesión". Conserva el fix de accesibilidad:
/// hit area >=44dp (padding interno + HitTestBehavior.opaque) y rol botón
/// vía Semantics — mismo criterio que el link de login.
/// Loading: IgnorePointer bloquea sin atenuar (convención) — el flag
/// llega por parámetro desde la propuesta 011, cuando se desacopló de
/// RegisterCubit para reutilizarlo también en /forgot-password.
class RegisterLoginFooter extends StatelessWidget {
  const RegisterLoginFooter({
    super.key,
    required this.onTap,
    required this.isInProgress,
  });

  /// Paso 1 → /login; en pasos 2-3 la navegación sigue siendo a /login
  /// (el link siempre abandona el wizard — misma regla que la flecha
  /// del paso 1, NO como la flecha de pasos 2-3).
  final VoidCallback onTap;

  /// true mientras el submit del wizard está en vuelo — bloquea el link.
  final bool isInProgress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return IgnorePointer(
      ignoring: isInProgress,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l10n.registerHasAccount, style: theme.textTheme.bodyMedium),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Semantics(
              button: true,
              label: l10n.registerLoginLink,
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Text(
                  l10n.registerLoginLink,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
