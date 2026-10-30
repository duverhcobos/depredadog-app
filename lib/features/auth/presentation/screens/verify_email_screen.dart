import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/routes/auth_guard.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/failures/auth_failure.dart';
import '../cubit/verify_email_cubit.dart';
import '../cubit/verify_email_state.dart';
import '../widgets/verify_email_form_fields.dart';

/// Pantalla de verificación de correo — se llega acá cuando /auth/login
/// responde "correo no verificado" (403). Patrón dos clases (ui-design-standard).
class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VerifyEmailCubit>(
      create: (context) => locator<VerifyEmailCubit>(param1: email),
      child: const _VerifyEmailView(),
    );
  }
}

class _VerifyEmailView extends StatefulWidget {
  const _VerifyEmailView();

  @override
  State<_VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<_VerifyEmailView> {
  late final FocusNode _codeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Sin email no hay destinatario del código — la ruta solo se alcanza
    // legítimamente desde login (403 EmailNotVerifiedFailure); cualquier
    // acceso directo con extra vacío devuelve al login.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<VerifyEmailCubit>().state.email.isEmpty) {
        context.go(AuthGuard.loginRoute);
      }
    });
  }

  @override
  void dispose() {
    _codeFocus.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<VerifyEmailCubit>().submit();
  }

  void _backToLogin() {
    // Submit o reenvío en vuelo: el back espera — bloqueado, no atenuado
    // (misma homologación que register — hallazgo revisor-ui).
    final s = context.read<VerifyEmailCubit>().state;
    if (s.isInProgress || s.isResending) return;
    context.go(AuthGuard.loginRoute);
  }

  /// La UI nunca muestra el texto crudo del backend (i18n-workflow) —
  /// cada AuthFailure mapea a su copy; las claves loginError* se reusan
  /// porque el texto es el mismo concepto (rate limit, sin red, genérico).
  String _authErrorMessage(AppLocalizations l10n, AuthFailure failure) =>
      switch (failure) {
        InvalidCodeFailure() => l10n.verifyEmailErrorInvalidCode,
        TooManyAttemptsFailure() => l10n.loginErrorTooManyAttempts,
        NoConnectionFailure() => l10n.loginErrorNoConnection,
        _ => l10n.loginErrorGeneric,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final email = context.read<VerifyEmailCubit>().state.email;
    return PopScope(
      canPop: false,
      // go() reemplazó el stack al llegar acá — sin esto, el back nativo
      // de Android (botón/gesto) no tendría nada que "popear" y no haría
      // nada útil. Mismo destino que la flecha explícita: /login.
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _backToLogin();
      },
      child: Scaffold(
        body: SafeArea(
          // Columna externa: la flecha queda FIJA arriba de la pantalla
          // (fuera del bloque que se centra) — antes vivía como primer
          // hijo de la Column centrada y "flotaba" a media pantalla,
          // arrastrada por el alto del resto del contenido (bug reportado
          // por el usuario).
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // La flecha también queda bloqueada durante submit/reenvío
              // (IgnorePointer — apariencia intacta).
              BlocBuilder<VerifyEmailCubit, VerifyEmailState>(
                buildWhen: (p, c) =>
                    p.isInProgress != c.isInProgress ||
                    p.isResending != c.isResending,
                builder: (context, state) => IgnorePointer(
                  ignoring: state.isInProgress || state.isResending,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: l10n.commonBack,
                    onPressed: _backToLogin,
                  ),
                ),
              ),
              Expanded(
                // Dos listeners separados: con uno solo, el `else if
                // (resendTick > 0)` evaluaba el ESTADO actual en cualquier
                // transición y mostraba "Código reenviado" sin reenviar nada
                // (ej. failure→initial tras un reenvío real). Cada efecto
                // escucha su propio cambio (revisor-ui).
                child: MultiBlocListener(
                  listeners: [
                    BlocListener<VerifyEmailCubit, VerifyEmailState>(
                      listenWhen: (prev, curr) => prev.status != curr.status,
                      listener: (context, state) {
                        if (state.status == VerifyEmailStatus.success) {
                          TextInput.finishAutofillContext();
                          // Verificar emite sesión (auto-login) — directo
                          // a /home, sin re-pedir credenciales.
                          context.go(AuthGuard.homeRoute);
                        } else if (state.status == VerifyEmailStatus.failure) {
                          _codeFocus.requestFocus();
                          AppToast.error(context, l10n.verifyEmailFormInvalid);
                        } else if (state.status ==
                                VerifyEmailStatus.authError &&
                            state.authFailure != null) {
                          // Refocus solo si el problema es el código — un
                          // 429 o sin red no tienen nada que corregir ahí.
                          if (state.authFailure is InvalidCodeFailure) {
                            _codeFocus.requestFocus();
                          }
                          AppToast.error(
                            context,
                            _authErrorMessage(l10n, state.authFailure!),
                          );
                        }
                      },
                    ),
                    BlocListener<VerifyEmailCubit, VerifyEmailState>(
                      listenWhen: (prev, curr) =>
                          prev.resendTick != curr.resendTick,
                      listener: (context, state) {
                        AppToast.success(
                          context,
                          l10n.verifyEmailResendSuccess,
                        );
                      },
                    ),
                  ],
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Ícono de marca (sobre+check con los colores
                          // oficiales) — elemento firma, no un Material icon
                          // genérico (revisor-ui). Decorativo para TalkBack:
                          // el headline ya lo describe.
                          ExcludeSemantics(
                            child: SvgPicture.asset(
                              'assets/images/icono_verificar_correo.svg',
                              height: 80,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            l10n.verifyEmailHeadline,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.verifyEmailSubtitle(email),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          VerifyEmailFormFields(
                            codeFocus: _codeFocus,
                            onSubmit: _submit,
                          ),
                          const SizedBox(height: 16),
                          BlocBuilder<VerifyEmailCubit, VerifyEmailState>(
                            buildWhen: (p, c) =>
                                p.status != c.status ||
                                p.isResending != c.isResending,
                            builder: (context, state) {
                              // La Column padre ya es CrossAxisAlignment
                              // .stretch — el botón ocupa todo el ancho solo.
                              // Convención loading: spinner DENTRO del botón
                              // (color onPrimary), el resto de controles ya
                              // queda bloqueado por sus propios `enabled`.
                              // Inerte durante isResending también: el
                              // reenvío invalida el código en el server.
                              return ElevatedButton(
                                onPressed:
                                    (state.isInProgress || state.isResending)
                                    ? () {}
                                    : _submit,
                                child: state.isInProgress
                                    ? SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: theme.colorScheme.onPrimary,
                                        ),
                                      )
                                    : Text(l10n.verifyEmailButton),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          BlocBuilder<VerifyEmailCubit, VerifyEmailState>(
                            buildWhen: (p, c) =>
                                p.resendCooldown != c.resendCooldown ||
                                p.isResending != c.isResending ||
                                p.isInProgress != c.isInProgress,
                            builder: (context, state) {
                              // Loading: IgnorePointer bloquea sin atenuar
                              // (convención). El disabled visible queda solo
                              // para el cooldown — es su estado semántico.
                              return IgnorePointer(
                                ignoring: state.isInProgress,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      l10n.verifyEmailResendQuestion,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    TextButton(
                                      onPressed: state.canResend
                                          ? () => context
                                                .read<VerifyEmailCubit>()
                                                .resend()
                                          : null,
                                      child: Text(
                                        state.resendCooldown > 0
                                            ? l10n.verifyEmailResendIn(
                                                state.resendCooldown,
                                              )
                                            : l10n.verifyEmailResend,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
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
