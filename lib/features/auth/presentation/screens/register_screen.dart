import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/auth_guard.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/register_cubit.dart';
import '../cubit/register_state.dart';
import '../widgets/register_login_footer.dart';
import '../widgets/register_review_card.dart';
import '../widgets/register_step1_fields.dart';
import '../widgets/register_step2_fields.dart';
import '../widgets/register_step_header.dart';
import '../widgets/register_stepper.dart';

/// Pantalla de registro — FASE PRESENTACIÓN (propuesta 009): wizard de 3
/// pasos con stepper visual (datos → cuenta → revisión). El submit sigue
/// simulado (delay → éxito → /verify-email con el email tipeado).
/// Patrón dos clases: `RegisterScreen` provee el cubit, `_RegisterView`
/// renderiza; los campos viven en `RegisterStepXFields`.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RegisterCubit>(
      // BlocProvider local (sin locator): el cubit simulado no tiene
      // dependencias. Cuando llegue la integración se registrará en DI
      // como LoginCubit/VerifyEmailCubit.
      create: (context) => RegisterCubit(),
      child: const _RegisterView(),
    );
  }
}

class _RegisterView extends StatefulWidget {
  const _RegisterView();

  @override
  State<_RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<_RegisterView> {
  // Controllers/focus se poseen en State y se disponen — nunca en build.
  // Sobreviven al cambio de paso: volver atrás conserva lo tipeado.
  late final TextEditingController _firstName = TextEditingController();
  late final TextEditingController _secondName = TextEditingController();
  late final TextEditingController _firstLastName = TextEditingController();
  late final TextEditingController _secondLastName = TextEditingController();
  late final TextEditingController _email = TextEditingController();
  late final TextEditingController _phone = TextEditingController();
  late final TextEditingController _password = TextEditingController();
  late final TextEditingController _confirmPassword = TextEditingController();
  late final FocusNode _firstNameFocus = FocusNode();
  late final FocusNode _secondNameFocus = FocusNode();
  late final FocusNode _firstLastNameFocus = FocusNode();
  late final FocusNode _secondLastNameFocus = FocusNode();
  late final FocusNode _emailFocus = FocusNode();
  late final FocusNode _phoneFocus = FocusNode();
  late final FocusNode _passwordFocus = FocusNode();
  late final FocusNode _confirmPasswordFocus = FocusNode();
  late final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _firstName.dispose();
    _secondName.dispose();
    _firstLastName.dispose();
    _secondLastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _firstNameFocus.dispose();
    _secondNameFocus.dispose();
    _firstLastNameFocus.dispose();
    _secondLastNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Botón primario del wizard: "Continuar" valida el paso y avanza;
  /// "Crear cuenta" (último paso) dispara el submit simulado.
  void _onPrimaryPressed() {
    FocusScope.of(context).unfocus();
    final cubit = context.read<RegisterCubit>();
    if (cubit.state.isLastStep) {
      cubit.submit();
    } else {
      cubit.nextStep();
    }
  }

  /// Back NATIVO (PopScope): en paso 1 abandona a /login; en pasos 2-3
  /// retrocede al paso anterior sin salir del registro. La flecha
  /// superior ya NO usa esta vía — sale directo a /login en cualquier
  /// paso (abandonar el registro); el retroceso por UI es del botón
  /// "Atrás".
  void _back() {
    final cubit = context.read<RegisterCubit>();
    // Submit en vuelo (paso 3): el back espera — convención de bloqueo.
    if (cubit.state.isInProgress) return;
    if (cubit.state.isFirstStep) {
      _backToLogin();
    } else {
      FocusScope.of(context).unfocus();
      cubit.prevStep();
    }
  }

  /// Volver a /login: pop cuando la pantalla quedó apilada (conserva lo
  /// tipeado en login); go() como fallback si el stack quedó vacío
  /// (deep link directo) — patrón verify_email_screen.
  void _backToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AuthGuard.loginRoute);
    }
  }

  /// Al cambiar de paso: scroll al tope (el offset anterior no debe
  /// arrastrarse). SIN autofocus — el teclado solo abre al tocar un campo
  /// o al fallar la validación (decisión del usuario: el foco automático
  /// al entrar a un paso se sentía invasivo).
  void _onStepChanged(BuildContext context, RegisterState state) {
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Foco al primer campo inválido DEL PASO en orden visual (forms skill) —
  /// los opcionales nunca son inválidos y quedan fuera de la cadena; la
  /// revisión (paso 3) no tiene campos que enfocar.
  void _focusFirstInvalid(RegisterState state) {
    if (state.currentStep == 0) {
      if (state.firstName.isNotValid) {
        _firstNameFocus.requestFocus();
      } else if (state.firstLastName.isNotValid) {
        _firstLastNameFocus.requestFocus();
      } else if (state.phone.isNotValid) {
        _phoneFocus.requestFocus();
      }
    } else if (state.currentStep == 1) {
      if (state.email.isNotValid) {
        _emailFocus.requestFocus();
      } else if (state.password.isNotValid) {
        _passwordFocus.requestFocus();
      } else if (state.confirmPassword.isNotValid) {
        _confirmPasswordFocus.requestFocus();
      }
    }
  }

  /// Contenido del paso: header (título+subtítulo) + cuerpo. La key por
  /// paso es lo que AnimatedSwitcher usa para detectar el cambio.
  Widget _buildStep(int step) {
    final Widget body = switch (step) {
      0 => RegisterStep1Fields(
        firstNameController: _firstName,
        secondNameController: _secondName,
        firstLastNameController: _firstLastName,
        secondLastNameController: _secondLastName,
        phoneController: _phone,
        firstNameFocus: _firstNameFocus,
        secondNameFocus: _secondNameFocus,
        firstLastNameFocus: _firstLastNameFocus,
        secondLastNameFocus: _secondLastNameFocus,
        phoneFocus: _phoneFocus,
        onContinue: _onPrimaryPressed,
      ),
      1 => RegisterStep2Fields(
        emailController: _email,
        passwordController: _password,
        confirmPasswordController: _confirmPassword,
        emailFocus: _emailFocus,
        passwordFocus: _passwordFocus,
        confirmPasswordFocus: _confirmPasswordFocus,
        onContinue: _onPrimaryPressed,
      ),
      _ => const RegisterReviewCard(),
    };
    return Column(
      key: ValueKey('register_step_$step'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const RegisterStepHeader(), const SizedBox(height: 24), body],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      // Back nativo = convención wizard: paso 1 → /login (aunque el
      // stack quedara vacío), pasos 2-3 → paso anterior. Distinto de la
      // flecha superior, que siempre abandona a /login.
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          // Columna externa: la flecha queda FIJA arriba (fuera del bloque
          // que scrollea) — misma solución que verify-email. Sin imagotipo
          // en los pasos (propuesta): solo flecha + stepper + título.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // La flecha SIEMPRE abandona a /login (cualquier paso) y
              // queda bloqueada durante el submit (IgnorePointer —
              // apariencia intacta, hallazgo revisor-ui).
              BlocBuilder<RegisterCubit, RegisterState>(
                buildWhen: (p, c) => p.isInProgress != c.isInProgress,
                builder: (context, state) => IgnorePointer(
                  ignoring: state.isInProgress,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: l10n.commonBack,
                    onPressed: _backToLogin,
                  ),
                ),
              ),
              // Stepper FIJO (fuera del scroll): el progreso no se puede
              // perder de vista scrolleando — patrón wizard (revisor-ui).
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: RegisterStepper(),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BlocListener<RegisterCubit, RegisterState>(
                  listenWhen: (prev, curr) => prev.status != curr.status,
                  listener: (context, state) {
                    if (state.status == RegisterStatus.success) {
                      // Cerramos autofill SIN guardar (shouldSave: false):
                      // /verify-email autofocusa su campo OTP y el modal
                      // "¿Guardar contraseña?" de GMS competiría con el
                      // teclado — misma carrera que login→verify. Al
                      // integrar /auth/register se decide el shouldSave.
                      TextInput.finishAutofillContext(shouldSave: false);
                      context.go(
                        AuthGuard.verifyEmailRoute,
                        extra: state.email.value,
                      );
                    } else if (state.status == RegisterStatus.failure) {
                      _focusFirstInvalid(state);
                      AppToast.error(context, l10n.loginFormInvalid);
                    }
                    // authError llega con la integración (409/400/429) —
                    // el submit simulado nunca lo emite.
                  },
                  child: BlocListener<RegisterCubit, RegisterState>(
                    // Cambio de paso: reset de scroll + foco al primer
                    // campo del paso entrante.
                    listenWhen: (p, c) => p.currentStep != c.currentStep,
                    listener: _onStepChanged,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: AutofillGroup(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Transición entre pasos: fade + slide leve;
                            // AnimatedSize suaviza el cambio de altura
                            // (paso 1→2 encoge ~200px — sin salto seco).
                            BlocBuilder<RegisterCubit, RegisterState>(
                              buildWhen: (p, c) =>
                                  p.currentStep != c.currentStep,
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
                            // queda bloqueado por IgnorePointer — nada de
                            // atenuar ni spinner suelto.
                            BlocBuilder<RegisterCubit, RegisterState>(
                              buildWhen: (p, c) =>
                                  p.status != c.status ||
                                  p.currentStep != c.currentStep,
                              builder: (context, state) {
                                final inProgress = state.isInProgress;
                                return Row(
                                  children: [
                                    // "Atrás" retrocede un paso sin
                                    // abandonar — solo en pasos 2-3;
                                    // en paso 1 el primario ocupa todo
                                    // el ancho.
                                    if (!state.isFirstStep) ...[
                                      TextButton(
                                        // Inerte durante inProgress
                                        // igual que el primario
                                        // (convención).
                                        onPressed: inProgress
                                            ? () {}
                                            : () => context
                                                  .read<RegisterCubit>()
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
                                        onPressed: inProgress
                                            ? () {}
                                            : _onPrimaryPressed,
                                        child: inProgress
                                            ? SizedBox(
                                                height: 22,
                                                width: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: theme
                                                          .colorScheme
                                                          .onPrimary,
                                                    ),
                                              )
                                            : Text(
                                                state.isLastStep
                                                    ? l10n.registerButton
                                                    : l10n.registerContinue,
                                              ),
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
                            // es del botón "Atrás".
                            RegisterLoginFooter(onTap: _backToLogin),
                          ],
                        ),
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
