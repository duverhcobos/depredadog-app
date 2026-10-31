import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';
import 'register_field.dart';

/// Paso 2 "Tu correo y tu llave" (propuesta 009): correo + contraseña con
/// ojo y helper "Mínimo 8 caracteres" + confirmar con ojo independiente.
/// Controllers/FocusNodes los posee el State de la pantalla.
/// Misma convención de loading: IgnorePointer sin atenuar.
class RegisterStep2Fields extends StatelessWidget {
  const RegisterStep2Fields({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.emailFocus,
    required this.passwordFocus,
    required this.confirmPasswordFocus,
    required this.onContinue,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final FocusNode confirmPasswordFocus;

  /// Acción "done" del teclado en el último campo = "Continuar".
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<RegisterCubit, RegisterState>(
      buildWhen: (p, c) => p.isInProgress != c.isInProgress,
      builder: (context, progressState) {
        return IgnorePointer(
          ignoring: progressState.isInProgress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RegisterField(
                key: const ValueKey('register_email'),
                label: l10n.registerEmailLabel,
                controller: emailController,
                focusNode: emailFocus,
                hintText: l10n.loginEmailHint,
                prefixIcon: const Icon(Icons.mail_outline),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                errorText: (s) => switch (s.emailErrorKey()) {
                  'empty' => l10n.loginEmailRequired,
                  'invalid' => l10n.registerEmailInvalid,
                  // 409 del submit (propuesta 010): prima sobre formato.
                  'taken' => l10n.registerEmailTaken,
                  _ => null,
                },
                onChanged: (v) => context.read<RegisterCubit>().emailChanged(v),
              ),
              const SizedBox(height: 8),
              RegisterField(
                key: const ValueKey('register_password'),
                label: l10n.registerPasswordLabel,
                controller: passwordController,
                focusNode: passwordFocus,
                // El hint vive BAJO el campo (helperText), no dentro —
                // siempre visible, no desaparece al teclear (propuesta).
                helperText: l10n.registerPasswordHint,
                prefixIcon: const Icon(Icons.lock_outline),
                keyboardType: TextInputType.visiblePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                obscure: (s) => s.obscurePassword,
                suffix: (context, s) => _eyeButton(
                  obscure: s.obscurePassword,
                  l10n: l10n,
                  onToggle: () =>
                      context.read<RegisterCubit>().togglePasswordVisibility(),
                ),
                errorText: (s) => switch (s.passwordErrorKey()) {
                  'empty' => l10n.registerPasswordRequired,
                  'tooShort' => l10n.registerPasswordInvalid,
                  _ => null,
                },
                onChanged: (v) =>
                    context.read<RegisterCubit>().passwordChanged(v),
              ),
              const SizedBox(height: 8),
              RegisterField(
                key: const ValueKey('register_confirm_password'),
                label: l10n.registerConfirmPasswordLabel,
                controller: confirmPasswordController,
                focusNode: confirmPasswordFocus,
                hintText: l10n.registerConfirmPasswordHint,
                prefixIcon: const Icon(Icons.lock_outline),
                keyboardType: TextInputType.visiblePassword,
                // Último campo del paso: "done" dispara Continuar.
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                // Ojo independiente del de contraseña (propuesta).
                obscure: (s) => s.obscureConfirmPassword,
                suffix: (context, s) => _eyeButton(
                  obscure: s.obscureConfirmPassword,
                  l10n: l10n,
                  onToggle: () => context
                      .read<RegisterCubit>()
                      .toggleConfirmPasswordVisibility(),
                ),
                errorText: (s) => switch (s.confirmPasswordErrorKey()) {
                  'empty' => l10n.registerConfirmRequired,
                  'mismatch' => l10n.registerConfirmMismatch,
                  _ => null,
                },
                onChanged: (v) =>
                    context.read<RegisterCubit>().confirmPasswordChanged(v),
                onFieldSubmitted: (_) => onContinue(),
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
