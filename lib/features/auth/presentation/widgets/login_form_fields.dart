import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';
import 'custom_text_field.dart';

/// SOLID (SRP): los campos del formulario de login viven aquí — la pantalla
/// solo orquesta (bloc-patterns: sin BlocBuilder de campos inline).
/// Controllers/FocusNodes los posee el State de la pantalla y llegan por
/// parámetro; las claves de error ('empty'/'invalid'/'tooShort') vienen del
/// state y se mapean a l10n acá.
class LoginFormFields extends StatelessWidget {
  const LoginFormFields({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.emailFocus,
    required this.passwordFocus,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BlocBuilder<LoginCubit, LoginState>(
          buildWhen: (p, c) =>
              p.email != c.email || p.showEmailError != c.showEmailError,
          builder: (context, state) {
            return CustomTextField(
              key: const ValueKey('login_email'),
              label: l10n.loginEmailLabel,
              controller: emailController,
              focusNode: emailFocus,
              hintText: l10n.loginEmailHint,
              prefixIcon: const Icon(Icons.mail_outline),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              errorText: switch (state.emailErrorKey()) {
                'empty' => l10n.loginEmailRequired,
                'invalid' => l10n.loginEmailError,
                _ => null,
              },
              onChanged: (v) => context.read<LoginCubit>().emailChanged(v),
            );
          },
        ),
        const SizedBox(height: 8),
        BlocBuilder<LoginCubit, LoginState>(
          buildWhen: (p, c) =>
              p.password != c.password ||
              p.obscurePassword != c.obscurePassword ||
              p.showPasswordError != c.showPasswordError,
          builder: (context, state) {
            return CustomTextField(
              key: const ValueKey('login_password'),
              label: l10n.loginPasswordLabel,
              controller: passwordController,
              focusNode: passwordFocus,
              obscureText: state.obscurePassword,
              hintText: l10n.loginPasswordHint,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: state.obscurePassword
                    ? l10n.loginShowPassword
                    : l10n.loginHidePassword,
                icon: Icon(
                  state.obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    context.read<LoginCubit>().togglePasswordVisibility(),
              ),
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              errorText: switch (state.passwordErrorKey()) {
                'empty' => l10n.loginPasswordRequired,
                'tooShort' => l10n.loginPasswordError,
                _ => null,
              },
              onChanged: (v) => context.read<LoginCubit>().passwordChanged(v),
              onFieldSubmitted: (_) => onSubmit(),
            );
          },
        ),
        Row(
          children: [
            BlocBuilder<LoginCubit, LoginState>(
              buildWhen: (p, c) => p.rememberMe != c.rememberMe,
              builder: (context, state) {
                return GestureDetector(
                  onTap: () => context
                      .read<LoginCubit>()
                      .rememberMeChanged(!state.rememberMe),
                  child: Row(
                    children: [
                      Checkbox(
                        value: state.rememberMe,
                        onChanged: (v) => context
                            .read<LoginCubit>()
                            .rememberMeChanged(v ?? false),
                        visualDensity: VisualDensity.compact,
                      ),
                      Text(
                        l10n.loginRememberMe,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                // PROVISIONAL: /forgot-password llega en su propia
                // pantalla — por ahora aviso.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.comingSoon)),
                );
              },
              child: Text(
                l10n.loginForgotPassword,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
