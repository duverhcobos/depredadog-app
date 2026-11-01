import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/forgot_password_cubit.dart';
import '../cubit/forgot_password_state.dart';
import 'form_field.dart';

/// Paso 1 "¿Olvidaste tu contraseña?" (propuesta 011): solo el correo de la
/// cuenta. Controller/FocusNode los posee el State de la pantalla — al
/// volver del paso 2 el correo sigue intacto.
/// Convención de loading (ui-design-standard): mientras el submit
/// resuelve, TODO lo interactivo queda BLOQUEADO con IgnorePointer sin
/// atenuar.
class ForgotStep1Email extends StatelessWidget {
  const ForgotStep1Email({
    super.key,
    required this.emailController,
    required this.emailFocus,
    required this.onSendCode,
  });

  final TextEditingController emailController;
  final FocusNode emailFocus;

  /// Acción "done" del teclado = "Enviar código" (el primario del paso).
  final VoidCallback onSendCode;

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
                  l10n.forgotTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.forgotSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              FormBlocField<ForgotPasswordCubit, ForgotPasswordState>(
                key: const ValueKey('forgot_email'),
                label: l10n.registerEmailLabel,
                controller: emailController,
                focusNode: emailFocus,
                hintText: l10n.loginEmailHint,
                prefixIcon: const Icon(Icons.mail_outline),
                keyboardType: TextInputType.emailAddress,
                // Único campo del paso: "done" dispara Enviar código.
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.username],
                errorText: (s) => switch (s.emailErrorKey()) {
                  'empty' => l10n.loginEmailRequired,
                  'invalid' => l10n.registerEmailInvalid,
                  _ => null,
                },
                onChanged: (v) =>
                    context.read<ForgotPasswordCubit>().emailChanged(v),
                onFieldSubmitted: (_) => onSendCode(),
              ),
            ],
          ),
        );
      },
    );
  }
}
