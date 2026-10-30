import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';

/// Footer persistente de los 3 pasos del wizard (propuesta 009):
/// "¿Ya tienes cuenta? Inicia sesión". Conserva el fix de accesibilidad:
/// hit area >=44dp (padding interno + HitTestBehavior.opaque) y rol botón
/// vía Semantics — mismo criterio que el link de login.
/// Loading: IgnorePointer bloquea sin atenuar (convención).
class RegisterLoginFooter extends StatelessWidget {
  const RegisterLoginFooter({super.key, required this.onTap});

  /// Paso 1 → /login; en pasos 2-3 la navegación sigue siendo a /login
  /// (el link siempre abandona el registro — misma regla que la flecha
  /// del paso 1, NO como la flecha de pasos 2-3).
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return BlocBuilder<RegisterCubit, RegisterState>(
      buildWhen: (p, c) => p.isInProgress != c.isInProgress,
      builder: (context, state) {
        return IgnorePointer(
          ignoring: state.isInProgress,
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
      },
    );
  }
}
