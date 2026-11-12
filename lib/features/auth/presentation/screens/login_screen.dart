import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/routes/auth_guard.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/failures/auth_failure.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/login_brand_header.dart';
import '../widgets/login_form_fields.dart';

/// Pantalla de login — primera de la feature auth.
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

  /// El `?from=` del propio URI, sanitizado (§031 — retorno post-login
  /// a donde estaba el usuario: checkout, detalle de pedido, etc.).
  String? get _from => AuthGuard.sanitizeFrom(
    GoRouterState.of(context).uri.queryParameters['from'],
  );

  /// Anexa el `?from=` actual a una ruta de auth — el retorno
  /// sobrevive al cambio de pantalla (login↔register↔verify/forgot).
  String _withFrom(String route) {
    final from = _from;
    return from == null ? route : '$route?from=${Uri.encodeComponent(from)}';
  }

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

  /// La UI nunca muestra el texto crudo del backend — cada AuthFailure
  /// mapea a su copy en español (i18n-workflow). EmailNotVerifiedFailure
  /// no tiene toast: navega a /verify-email (la pantalla se explica sola).
  String _authErrorMessage(AppLocalizations l10n, AuthFailure failure) =>
      switch (failure) {
        InvalidCredentialsFailure() => l10n.loginErrorInvalidCredentials,
        EmailNotVerifiedFailure() => l10n.loginErrorEmailNotVerified,
        // InvalidCodeFailure solo lo produce /auth/verify-email —
        // SessionExpiredFailure y NoStoredSessionFailure solo salen de
        // restoreSession (splash), y EmailAlreadyRegisteredFailure solo
        // viene de /auth/register: los cuatro son inalcanzables acá y
        // caen al genérico por exhaustividad del sealed.
        InvalidCodeFailure() => l10n.loginErrorGeneric,
        SessionExpiredFailure() => l10n.loginErrorGeneric,
        NoStoredSessionFailure() => l10n.loginErrorGeneric,
        EmailAlreadyRegisteredFailure() => l10n.loginErrorGeneric,
        AccountSuspendedFailure() => l10n.loginErrorAccountSuspended,
        TooManyAttemptsFailure() => l10n.loginErrorTooManyAttempts,
        NoConnectionFailure() => l10n.loginErrorNoConnection,
        UnknownAuthFailure() => l10n.loginErrorGeneric,
      };

  /// Errores del flujo Google (propuesta 014): un solo toast genérico —
  /// solo suspended / sin conexión / throttle conservan su copy porque
  /// describen algo accionable (decisión del usuario). El 401 'Invalid
  /// Google token', los errores del SDK y los inalcanzables de otros
  /// endpoints caen al genérico de Google por exhaustividad del sealed.
  String _googleErrorMessage(AppLocalizations l10n, AuthFailure failure) =>
      switch (failure) {
        AccountSuspendedFailure() => l10n.loginErrorAccountSuspended,
        TooManyAttemptsFailure() => l10n.loginErrorTooManyAttempts,
        NoConnectionFailure() => l10n.loginErrorNoConnection,
        InvalidCredentialsFailure() => l10n.googleSignInError,
        EmailNotVerifiedFailure() => l10n.googleSignInError,
        InvalidCodeFailure() => l10n.googleSignInError,
        SessionExpiredFailure() => l10n.googleSignInError,
        NoStoredSessionFailure() => l10n.googleSignInError,
        EmailAlreadyRegisteredFailure() => l10n.googleSignInError,
        UnknownAuthFailure() => l10n.googleSignInError,
      };

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
              // En éxito Google no se guardan las credenciales tipeadas:
              // nunca se enviaron y podrían estar erradas.
              TextInput.finishAutofillContext(shouldSave: !state.isGoogleAuth);
              // §031 — de vuelta a donde estaba (?from=) o a la carta.
              context.go(_from ?? AuthGuard.homeRoute);
            } else if (state.status == LoginStatus.failure) {
              // Foco al primer campo inválido en orden visual (forms skill).
              if (state.email.isNotValid) {
                _emailFocus.requestFocus();
              } else {
                _passwordFocus.requestFocus();
              }
              AppToast.error(context, l10n.loginFormInvalid);
            } else if (state.status == LoginStatus.authError &&
                state.authFailure != null) {
              if (state.isGoogleAuth) {
                // El flujo Google no tiene campos que señalar ni salida
                // propia: solo el toast.
                AppToast.error(
                  context,
                  _googleErrorMessage(l10n, state.authFailure!),
                );
              } else if (state.authFailure is EmailNotVerifiedFailure) {
                // El login no se completó: cerramos el contexto de
                // autofill SIN guardar — si la sesión queda abierta, al
                // navegar Android la "commitea" y GMS dispara el modal
                // "¿Guardar contraseña?" que compite con el teclado del
                // OTP (los dos se cierran mutuamente — bug del usuario).
                // Mismo patrón para cualquier otra salida del login que
                // no sea éxito (p. ej. /register cuando exista).
                TextInput.finishAutofillContext(shouldSave: false);
                // El usuario quedó a mitad del flujo de registro — lo
                // mandamos a verificar con su email ya escrito. El
                // ?from= viaja también: tras verificar vuelve al punto
                // donde se pidió la sesión (§031).
                context.go(
                  _withFrom(AuthGuard.verifyEmailRoute),
                  extra: state.email.value,
                );
              } else {
                AppToast.error(
                  context,
                  _authErrorMessage(l10n, state.authFailure!),
                );
              }
            }
          },
          child: Stack(
            children: [
              Center(
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
                        // ui-design-standard: el estado busy vive DENTRO del
                        // botón primario (spinner en lugar del texto) y el resto
                        // de controles interactivos queda bloqueado — nunca se
                        // reemplaza el grupo de acciones por un spinner suelto.
                        BlocBuilder<LoginCubit, LoginState>(
                          buildWhen: (p, c) => p.status != c.status,
                          builder: (context, state) {
                            final inProgress = state.isInProgress;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ElevatedButton(
                                  // Sigue "enabled" (color de marca intacto): el
                                  // busy se comunica con el spinner interno y el
                                  // cubit ignora re-entradas — deshabilitarlo lo
                                  // atenuaría a gris M3.
                                  onPressed: inProgress ? () {} : _submit,
                                  child: inProgress
                                      ? SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            // onPrimary (negro) sobre mostaza —
                                            // el default `primary` sería
                                            // invisible en este botón.
                                            color: theme.colorScheme.onPrimary,
                                          ),
                                        )
                                      : Text(l10n.loginButton),
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
                                // Misma convención que el formulario: bloqueo por
                                // IgnorePointer — apariencia intacta, solo se
                                // ignoran los toques mientras la petición resuelve.
                                IgnorePointer(
                                  ignoring: inProgress,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Sin gate de Environment (decisión del
                                      // usuario): si el client ID está vacío el
                                      // SDK falla y el usuario ve el toast
                                      // genérico — comportamiento real desde el
                                      // primer build.
                                      GoogleSignInButton(
                                        onPressed: () => context
                                            .read<LoginCubit>()
                                            .signInWithGoogle(),
                                      ),
                                      const SizedBox(height: 32),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            l10n.loginNoAccount,
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                          // Hit area >=44dp + rol botón:
                                          // padding interno + opaque.
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              // Salida del login sin éxito:
                                              // autofill se cierra SIN guardar
                                              // (misma razón que
                                              // EmailNotVerifiedFailure →
                                              // /verify-email — el modal "¿Guardar
                                              // contraseña?" no debe dispararse).
                                              TextInput.finishAutofillContext(
                                                shouldSave: false,
                                              );
                                              // El ?from= se propaga al
                                              // registro: crear cuenta
                                              // también devuelve al punto
                                              // pedido (§031).
                                              context.push(
                                                _withFrom(
                                                  AuthGuard.registerRoute,
                                                ),
                                              );
                                            },
                                            child: Semantics(
                                              button: true,
                                              label: l10n.loginRegisterLink,
                                              excludeSemantics: true,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 12,
                                                    ),
                                                child: Text(
                                                  l10n.loginRegisterLink,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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
              // §031 — el login ahora también llega por push (muros) o
              // por redirect del guard: flecha flotante de salida como
              // sus hermanas register/verify (patrón Positioned del
              // detalle). pop al muro cuando hay stack; si el guard
              // reemplazó la pila (raíz), vuelve a la carta. Bloqueada
              // durante el submit, igual que en register.
              Positioned(
                top: 4,
                left: 4,
                child: BlocBuilder<LoginCubit, LoginState>(
                  buildWhen: (p, c) => p.isInProgress != c.isInProgress,
                  builder: (context, state) => IgnorePointer(
                    ignoring: state.isInProgress,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: l10n.commonBack,
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(AuthGuard.homeRoute),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
