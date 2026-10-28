import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/login_brand_header.dart';
import '../widgets/login_form_fields.dart';

/// Pantalla de login — primera de la feature auth (fase presentación).
/// Patrón dos clases: `LoginScreen` provee el cubit local vía locator,
/// `_LoginView` renderiza; los campos viven en `LoginFormFields`.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LoginCubit>(
      create: (context) => locator<LoginCubit>(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  // Los controllers/focus se poseen en State y se disponen — nunca en build.
  late final TextEditingController _email = TextEditingController();
  late final TextEditingController _password = TextEditingController();
  late final FocusNode _emailFocus = FocusNode();
  late final FocusNode _passwordFocus = FocusNode();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<LoginCubit>().submit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: BlocListener<LoginCubit, LoginState>(
          listenWhen: (prev, curr) => prev.status != curr.status,
          listener: (context, state) {
            if (state.status == LoginStatus.success) {
              TextInput.finishAutofillContext(shouldSave: true);
              AppToast.success(context, l10n.loginDemoSuccess);
            } else if (state.status == LoginStatus.failure) {
              // Foco al primer campo inválido en orden visual (forms skill).
              if (state.email.isNotValid) {
                _emailFocus.requestFocus();
              } else {
                _passwordFocus.requestFocus();
              }
              AppToast.error(context, l10n.loginFormInvalid);
            }
          },
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: AutofillGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LoginBrandHeader(),
                    const SizedBox(height: 24),
                    LoginFormFields(
                      emailController: _email,
                      passwordController: _password,
                      emailFocus: _emailFocus,
                      passwordFocus: _passwordFocus,
                      onSubmit: _submit,
                    ),
                    const SizedBox(height: 16),
                    // ui-design-standard: en loading se reemplaza el grupo
                    // completo de acciones por un único spinner centrado.
                    BlocBuilder<LoginCubit, LoginState>(
                      buildWhen: (p, c) => p.status != c.status,
                      builder: (context, state) {
                        if (state.isInProgress) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton(
                              onPressed: _submit,
                              child: Text(l10n.loginButton),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    l10n.loginOrContinueWith,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const GoogleSignInButton(),
                            const SizedBox(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  l10n.loginNoAccount,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                GestureDetector(
                                  onTap: () {
                                    // PROVISIONAL: /register llega en su
                                    // propia pantalla — por ahora aviso.
                                    AppToast.success(context, l10n.comingSoon);
                                  },
                                  child: Text(
                                    l10n.loginRegisterLink,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
