import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/forgot_password_cubit.dart';
import '../cubit/forgot_password_state.dart';
import 'form_field.dart';

/// Paso 3 "Crea tu nueva contraseña" (propuesta 011): nueva contraseña con
/// ojo y helper "Mínimo 8 caracteres" + confirmar con ojo independiente
/// — mismos campos del paso de cuenta de /register (mismos inputs
/// Formz, mismas claves l10n).
/// Controllers/FocusNodes los posee el State de la pantalla.
/// Misma convención de loading: IgnorePointer sin atenuar.
class ForgotStep3Password extends StatelessWidget {
  const ForgotStep3Password({
    super.key,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.passwordFocus,
    required this.confirmPasswordFocus,
    required this.onSubmit,
  });

  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final FocusNode passwordFocus;
  final FocusNode confirmPasswordFocus;

  /// Acción "done" del teclado en el último campo = "Cambiar contraseña".
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
      buildWhen: (p, c) => p.isInProgress != c.isInProgress,
      builder: (context, progressState) {
        return IgnorePointer(
          ignoring: progressState.isInProgress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.forgotPasswordTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.forgotPasswordSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              FormBlocField<ForgotPasswordCubit, ForgotPasswordState>(
                key: const ValueKey('forgot_password'),
                label: l10n.forgotNewPasswordLabel,
                controller: passwordController,
                focusNode: passwordFocus,
                // Hint dentro (ejemplo, como confirmar) + regla BAJO el
                // campo (helperText) — el campo vacío sin placeholder
                // se veía "muerto" al lado del de confirmar.
                hintText: l10n.loginPasswordHint,
                helperText: l10n.registerPasswordHint,
                prefixIcon: const Icon(Icons.lock_outline),
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                obscure: (s) => s.obscurePassword,
                suffix: (context, s) => _eyeButton(
                  obscure: s.obscurePassword,
                  l10n: l10n,
                  onToggle: () => context
                      .read<ForgotPasswordCubit>()
                      .togglePasswordVisibility(),
                ),
                errorText: (s) => switch (s.passwordErrorKey()) {
                  'empty' => l10n.registerPasswordRequired,
                  'tooShort' => l10n.registerPasswordInvalid,
                  _ => null,
                },
                onChanged: (v) =>
                    context.read<ForgotPasswordCubit>().passwordChanged(v),
              ),
              const SizedBox(height: 8),
              FormBlocField<ForgotPasswordCubit, ForgotPasswordState>(
                key: const ValueKey('forgot_confirm_password'),
                label: l10n.registerConfirmPasswordLabel,
                controller: confirmPasswordController,
                focusNode: confirmPasswordFocus,
                hintText: l10n.registerConfirmPasswordHint,
                prefixIcon: const Icon(Icons.lock_outline),
                keyboardType: TextInputType.visiblePassword,
                // Último campo del wizard: "done" dispara Cambiar clave.
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                obscure: (s) => s.obscureConfirmPassword,
                suffix: (context, s) => _eyeButton(
                  obscure: s.obscureConfirmPassword,
                  l10n: l10n,
                  onToggle: () => context
                      .read<ForgotPasswordCubit>()
                      .toggleConfirmPasswordVisibility(),
                ),
                errorText: (s) => switch (s.confirmPasswordErrorKey()) {
                  'empty' => l10n.registerConfirmRequired,
                  'mismatch' => l10n.registerConfirmMismatch,
                  _ => null,
                },
                onChanged: (v) => context
                    .read<ForgotPasswordCubit>()
                    .confirmPasswordChanged(v),
                onFieldSubmitted: (_) => onSubmit(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Suffix de visibilidad compartido por contraseña y confirmación
  /// (cada uno con su flag/acción independientes).
  IconButton _eyeButton({
    required bool obscure,
    required AppLocalizations l10n,
    required VoidCallback onToggle,
  }) {
    return IconButton(
      tooltip: obscure ? l10n.loginShowPassword : l10n.loginHidePassword,
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
      onPressed: onToggle,
    );
  }
}
