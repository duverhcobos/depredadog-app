import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/routes/auth_guard.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/forgot_password_cubit.dart';
import '../cubit/forgot_password_state.dart';
import '../widgets/forgot_step1_email.dart';
import '../widgets/forgot_step2_code.dart';
import '../widgets/forgot_step3_password.dart';
import '../widgets/register_login_footer.dart';
import '../widgets/wizard_stepper.dart';

/// Pantalla de recuperación de contraseña — FASE PRESENTACIÓN
/// (propuesta 011): wizard de 3 pasos (correo → código OTP → nueva
/// clave) con submits SIMULADOS; el éxito navega a /home, espejo del
/// auto-login real del flujo. Mismo shell que /register: stepper fijo,
/// AnimatedSwitcher + AnimatedSize, back nativo por PopScope, scroll
/// reset, sin autofocus al cambiar de paso.
/// Patrón dos clases: `ForgotPasswordScreen` provee el cubit,
/// `_ForgotPasswordView` renderiza; los campos viven en `ForgotStepN*`.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ForgotPasswordCubit>(
      // Ya resuelve por locator: el cubit necesita AuthSession para la
      // sesión stub del éxito simulado (sin ella el guard rebota /home
      // → /login). Los use cases llegan con la integración.
      create: (_) => locator<ForgotPasswordCubit>(),
      child: const _ForgotPasswordView(),
    );
  }
}

class _ForgotPasswordView extends StatefulWidget {
  const _ForgotPasswordView();

  @override
  State<_ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<_ForgotPasswordView> {
  // Controllers/focus se poseen en State y se disponen — nunca en build.
  // Sobreviven al cambio de paso: volver atrás conserva lo tipeado.
  // (El del OTP vive en ForgotStep2Code — su texto lo guarda el cubit.)
  late final TextEditingController _email = TextEditingController();
  late final TextEditingController _password = TextEditingController();
  late final TextEditingController _confirmPassword = TextEditingController();
  late final FocusNode _emailFocus = FocusNode();
  late final FocusNode _codeFocus = FocusNode();
  late final FocusNode _passwordFocus = FocusNode();
  late final FocusNode _confirmPasswordFocus = FocusNode();
  late final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _emailFocus.dispose();
    _codeFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Botón primario del wizard: "Enviar código"/"Verificar" validan el
  /// paso y avanzan; "Cambiar contraseña" (último paso) dispara el
  /// submit simulado.
  void _onPrimaryPressed() {
    FocusScope.of(context).unfocus();
    final cubit = context.read<ForgotPasswordCubit>();
    if (cubit.state.isLastStep) {
      cubit.submit();
    } else {
      cubit.nextStep();
    }
  }

  /// Back NATIVO (PopScope): en paso 1 abandona a /login; en pasos 2-3
  /// retrocede al paso anterior. La flecha superior NO usa esta vía —
  /// sale directo a /login en cualquier paso (abandonar la recuperación).
  void _back() {
    final cubit = context.read<ForgotPasswordCubit>();
    // Submit o reenvío en vuelo: el back espera — convención de bloqueo
    // (isResending también: invalidaría el código que la petición limpia).
    if (cubit.state.isInProgress || cubit.state.isResending) return;
    if (cubit.state.isFirstStep) {
      _backToLogin();
    } else {
      FocusScope.of(context).unfocus();
      cubit.prevStep();
    }
  }

  /// Volver a /login: pop cuando la pantalla quedó apilada (conserva lo
  /// tipeado en login); go() como fallback si el stack quedó vacío
  /// (deep link directo) — patrón register/verify_email.
  void _backToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AuthGuard.loginRoute);
    }
  }

  /// Al cambiar de paso: scroll al tope. SIN autofocus — el teclado solo
  /// abre al tocar un campo o al fallar la validación (decisión del
  /// usuario: el foco automático al entrar a un paso se sentía invasivo).
  void _onStepChanged(BuildContext context, ForgotPasswordState state) {
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Foco al primer campo inválido DEL PASO en orden visual (forms skill).
  void _focusFirstInvalid(ForgotPasswordState state) {
    switch (state.currentStep) {
      case 0:
        if (state.email.isNotValid) _emailFocus.requestFocus();
      case 1:
        if (state.code.isNotValid) _codeFocus.requestFocus();
      case 2:
        if (state.password.isNotValid) {
          _passwordFocus.requestFocus();
        } else if (state.confirmPassword.isNotValid) {
          _confirmPasswordFocus.requestFocus();
        }
    }
  }

  /// Contenido del paso: header + cuerpo viven dentro de cada step
  /// widget; la key por paso es lo que AnimatedSwitcher usa para
  /// detectar el cambio.
  Widget _buildStep(int step) {
    return switch (step) {
      0 => ForgotStep1Email(
        key: const ValueKey('forgot_step_0'),
        emailController: _email,
        emailFocus: _emailFocus,
        onSendCode: _onPrimaryPressed,
      ),
      1 => ForgotStep2Code(
        key: const ValueKey('forgot_step_1'),
        codeFocus: _codeFocus,
        onVerify: _onPrimaryPressed,
      ),
      _ => ForgotStep3Password(
        key: const ValueKey('forgot_step_2'),
        passwordController: _password,
        confirmPasswordController: _confirmPassword,
        passwordFocus: _passwordFocus,
        confirmPasswordFocus: _confirmPasswordFocus,
        onSubmit: _onPrimaryPressed,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      // Back nativo = convención wizard: paso 1 → /login, pasos 2-3 →
      // paso anterior. Distinto de la flecha superior, que siempre
      // abandona la recuperación.
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          // Columna externa: flecha + stepper FIJOS arriba (fuera del
          // bloque que scrollea) — misma solución que register (revisor-ui).
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // La flecha SIEMPRE abandona a /login (cualquier paso) y
              // queda bloqueada durante submit/reenvío (IgnorePointer —
              // apariencia intacta).
              BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
                  buildWhen: (p, c) => p.currentStep != c.currentStep,
                  builder: (context, state) => WizardStepper(
                    labels: [
                      l10n.forgotStepEmailLabel,
                      l10n.forgotStepCodeLabel,
                      l10n.forgotStepPasswordLabel,
                    ],
                    currentStep: state.currentStep,
                    progressLabel: l10n.registerStepProgress(
                      state.currentStep + 1,
                      ForgotPasswordState.lastStep + 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                // Dos listeners con su propio listenWhen (patrón verify):
                // uno para status, otro para resendTick — un solo listener
                // con else-if encadenado puede disparar efectos falsos en
                // transiciones ajenas.
                child: MultiBlocListener(
                  listeners: [
                    BlocListener<ForgotPasswordCubit, ForgotPasswordState>(
                      listenWhen: (prev, curr) => prev.status != curr.status,
                      listener: (context, state) {
                        if (state.status == ForgotPasswordStatus.success) {
                          // Éxito → /home: se GUARDA el autofill — el
                          // flujo real termina en auto-login y el gestor
                          // debe ofrecer la NUEVA contraseña (patrón
                          // login; en register era shouldSave:false solo
                          // porque /verify-email autofocusa su OTP).
                          TextInput.finishAutofillContext(shouldSave: true);
                          context.go(AuthGuard.homeRoute);
                        } else if (state.status ==
                            ForgotPasswordStatus.failure) {
                          _focusFirstInvalid(state);
                          // Paso 2 solo tiene el código: su toast es el
                          // propio requisito ("Ingresa el código de 6
                          // dígitos" — clave compartida con verify);
                          // los pasos con campos de texto usan el
                          // genérico de formulario.
                          AppToast.error(
                            context,
                            state.currentStep == 1
                                ? l10n.verifyEmailFormInvalid
                                : l10n.loginFormInvalid,
                          );
                        }
                      },
                    ),
                    BlocListener<ForgotPasswordCubit, ForgotPasswordState>(
                      listenWhen: (prev, curr) =>
                          prev.resendTick != curr.resendTick,
                      listener: (context, state) {
                        AppToast.success(
                          context,
                          l10n.verifyEmailResendSuccess,
                        );
                      },
                    ),
                    BlocListener<ForgotPasswordCubit, ForgotPasswordState>(
                      // Cambio de paso: reset de scroll.
                      listenWhen: (p, c) => p.currentStep != c.currentStep,
                      listener: _onStepChanged,
                    ),
                  ],
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Transición entre pasos: fade + slide leve;
                          // AnimatedSize suaviza el cambio de altura —
                          // idéntica a register.
                          BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
                            buildWhen: (p, c) => p.currentStep != c.currentStep,
                            builder: (context, state) => AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, animation) {
                                  final slide =
                                      Tween<Offset>(
                                        begin: const Offset(0, 0.04),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOut,
                                        ),
                                      );
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: slide,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _buildStep(state.currentStep),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // ui-design-standard: el estado busy vive DENTRO
                          // del botón (spinner) y el resto de controles
                          // queda bloqueado por IgnorePointer.
                          BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
                            buildWhen: (p, c) =>
                                p.status != c.status ||
                                p.isResending != c.isResending ||
                                p.currentStep != c.currentStep,
                            builder: (context, state) {
                              // busy cubre submit Y reenvío: el primario
                              // queda inerte durante ambos (convención
                              // verify) pero el spinner solo pinta en el
                              // submit — el reenvío no es su petición.
                              final busy =
                                  state.isInProgress || state.isResending;
                              return Row(
                                children: [
                                  // "Atrás" retrocede un paso sin
                                  // abandonar — solo en pasos 2-3; en
                                  // paso 1 el primario ocupa todo el ancho.
                                  if (!state.isFirstStep) ...[
                                    TextButton(
                                      onPressed: busy
                                          ? () {}
                                          : () => context
                                                .read<ForgotPasswordCubit>()
                                                .prevStep(),
                                      child: Text(l10n.registerBackStep),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: ElevatedButton(
                                      // Sigue "enabled" (color de marca
                                      // intacto): el cubit ignora
                                      // re-entradas — deshabilitarlo lo
                                      // atenuaría a gris M3.
                                      onPressed: busy
                                          ? () {}
                                          : _onPrimaryPressed,
                                      child: state.isInProgress
                                          ? SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color:
                                                    theme.colorScheme.onPrimary,
                                              ),
                                            )
                                          : Text(switch (state.currentStep) {
                                              0 => l10n.forgotSendCode,
                                              1 => l10n.verifyEmailButton,
                                              _ => l10n.forgotSubmit,
                                            }),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          // El link "Inicia sesión" siempre abandona a
                          // /login (su propósito es ese), igual que la
                          // flecha superior — el retroceso entre pasos
                          // es del botón "Atrás". Widget compartido con
                          // /register (mismo copy).
                          BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
                            // isResending también bloquea: salir a login
                            // durante el reenvío abandona el flujo con la
                            // petición en vuelo (revisor-ui IMPORTANTE).
                            buildWhen: (p, c) =>
                                p.isInProgress != c.isInProgress ||
                                p.isResending != c.isResending,
                            builder: (context, state) => RegisterLoginFooter(
                              isInProgress:
                                  state.isInProgress || state.isResending,
                              onTap: _backToLogin,
                            ),
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
