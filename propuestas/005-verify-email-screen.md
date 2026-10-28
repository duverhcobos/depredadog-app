# Propuesta 005: VerifyEmailScreen (fase presentación)

Pantalla nueva, requerida antes de poder retomar la propuesta 004
(`/auth/login`): cuando el backend rechaza el login por correo sin
verificar, el usuario debe pasar por esta pantalla (código de 6 dígitos +
reenviar) antes de llegar a `/home` — así se asegura que todo usuario que
llega al home tiene un correo real y verificado (objetivo de marketing del
usuario).

Fase 1 del `screen-first-workflow`: **solo `presentation/`**, con datos
mock — ni `/auth/verify-email` ni `/auth/resend-verification` se integran
en esta propuesta (son sus propios ciclos, después de aprobar esta
pantalla y retomar 004).

También incluida: el cambio de **SnackBar → Toast** para feedback de error
(decisión del usuario) — se usa por primera vez acá y se retrofita al
SnackBar de "revisa los campos marcados" del login ya aprobado.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `pubspec.yaml` | `flutter pub add fluttertoast` (ya ejecutado) |
| `lib/core/widgets/app_toast.dart` | Nuevo — único punto que llama a `fluttertoast` |
| `lib/features/auth/presentation/widgets/custom_text_field.dart` | Actualizar — agrega `maxLength`/`inputFormatters` opcionales (no rompe los usos existentes) |
| `lib/features/auth/presentation/inputs/verify_email_inputs.dart` | Nuevo — `CodeInput` (Value Object, formz) |
| `lib/features/auth/presentation/cubit/verify_email_state.dart` | Nuevo |
| `lib/features/auth/presentation/cubit/verify_email_cubit.dart` | Nuevo — mock: submit simulado + cooldown de reenvío real (Timer) |
| `lib/features/auth/presentation/widgets/verify_email_form_fields.dart` | Nuevo |
| `lib/features/auth/presentation/screens/verify_email_screen.dart` | Nuevo |
| `lib/core/di/setup_di.dart` | Actualizar — `registerFactoryParam<VerifyEmailCubit, String, void>` |
| `lib/core/routes/app_router.dart` | Actualizar — `GoRoute` para `AuthGuard.verifyEmailRoute` (lee `state.extra` como email) |
| `lib/core/screens/splash_screen.dart` | Actualizar **TEMPORAL** — navega a `/verify-email` en vez de `/login` solo para que la veas; se revierte apenas la apruebes |
| `lib/features/auth/presentation/screens/login_screen.dart` | Actualizar — el SnackBar de "revisa los campos marcados" pasa a `AppToast.error` |
| `lib/l10n/app_es.arb` + `flutter gen-l10n` | Actualizar — claves nuevas de esta pantalla |

---

## 1. AppToast

**Ruta:** `lib/core/widgets/app_toast.dart`

```dart
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// SOLID (SRP): único punto que llama a fluttertoast — toda la app
/// muestra feedback efímero por acá, nunca SnackBar directo (decisión del
/// usuario — reemplaza el estándar anterior de ui-design-standard).
class AppToast {
  AppToast._();

  static void error(BuildContext context, String message) => _show(
    context,
    message,
    backgroundColor: Theme.of(context).colorScheme.error,
    textColor: Theme.of(context).colorScheme.onError,
  );

  static void success(BuildContext context, String message) => _show(
    context,
    message,
    backgroundColor: Theme.of(context).colorScheme.primary,
    textColor: Theme.of(context).colorScheme.onPrimary,
  );

  static void _show(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    required Color textColor,
  }) {
    Fluttertoast.showToast(
      msg: message,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: backgroundColor,
      textColor: textColor,
      toastLength: Toast.LENGTH_LONG,
    );
  }
}
```

---

## 2. CustomTextField (actualización — agrega maxLength/inputFormatters)

**Ruta:** `lib/features/auth/presentation/widgets/custom_text_field.dart`

**Antes:**
```dart
  const CustomTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.errorText,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
```
```dart
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
```

**Después:**
```dart
  const CustomTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.errorText,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? errorText;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
```
```dart
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
```

(agregar `import 'package:flutter/services.dart';` para `TextInputFormatter`)

---

## 3. CodeInput

**Ruta:** `lib/features/auth/presentation/inputs/verify_email_inputs.dart`

```dart
import 'package:formz/formz.dart';

/// SOLID (SRP): código de verificación — 6 dígitos numéricos.
enum CodeValidationError { empty, invalid }

final class CodeInput extends FormzInput<String, CodeValidationError> {
  const CodeInput.pure([super.value = '']) : super.pure();
  const CodeInput.dirty([super.value = '']) : super.dirty();

  static final _regex = RegExp(r'^\d{6}$');

  @override
  CodeValidationError? validator(String value) {
    if (value.isEmpty) return CodeValidationError.empty;
    if (!_regex.hasMatch(value)) return CodeValidationError.invalid;
    return null;
  }
}
```

---

## 4. VerifyEmailState

**Ruta:** `lib/features/auth/presentation/cubit/verify_email_state.dart`

```dart
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../inputs/verify_email_inputs.dart';

enum VerifyEmailStatus { initial, inProgress, success, failure }

/// `resendTick` incrementa en cada reenvío completado — BlocListener lo usa
/// para disparar el toast de éxito sin boolean "de un solo uso" propenso a
/// condiciones de carrera.
class VerifyEmailState extends Equatable {
  const VerifyEmailState({
    required this.email,
    this.code = const CodeInput.pure(),
    this.status = VerifyEmailStatus.initial,
    this.showCodeError = false,
    this.resendCooldown = 0,
    this.isResending = false,
    this.resendTick = 0,
  });

  final String email;
  final CodeInput code;
  final VerifyEmailStatus status;
  final bool showCodeError;

  /// Segundos restantes antes de poder reenviar de nuevo.
  final int resendCooldown;
  final bool isResending;
  final int resendTick;

  bool get isInProgress => status == VerifyEmailStatus.inProgress;
  bool get canResend => resendCooldown == 0 && !isResending;

  String? codeErrorKey() =>
      showCodeError && code.isNotValid ? code.error?.name : null;

  VerifyEmailState copyWith({
    CodeInput? code,
    VerifyEmailStatus? status,
    bool? showCodeError,
    int? resendCooldown,
    bool? isResending,
    int? resendTick,
  }) {
    return VerifyEmailState(
      email: email,
      code: code ?? this.code,
      status: status ?? this.status,
      showCodeError: showCodeError ?? this.showCodeError,
      resendCooldown: resendCooldown ?? this.resendCooldown,
      isResending: isResending ?? this.isResending,
      resendTick: resendTick ?? this.resendTick,
    );
  }

  @override
  List<Object?> get props => [
    email,
    code,
    status,
    showCodeError,
    resendCooldown,
    isResending,
    resendTick,
  ];
}
```

---

## 5. VerifyEmailCubit

**Ruta:** `lib/features/auth/presentation/cubit/verify_email_cubit.dart`

```dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../inputs/verify_email_inputs.dart';
import 'verify_email_state.dart';

/// PROVISIONAL (fase presentación): submit y reenvío simulados — la
/// integración real de /auth/verify-email y /auth/resend-verification
/// reemplaza estos métodos en sus propios ciclos. El cooldown de reenvío
/// SÍ es real (Timer), no es parte de lo que falta integrar.
class VerifyEmailCubit extends Cubit<VerifyEmailState> {
  VerifyEmailCubit({required String email})
    : super(VerifyEmailState(email: email));

  Timer? _cooldownTimer;

  void codeChanged(String value) => emit(
    state.copyWith(code: CodeInput.dirty(value), showCodeError: false),
  );

  Future<void> submit() async {
    if (state.isInProgress) return;
    if (!state.code.isValid) {
      emit(state.copyWith(status: VerifyEmailStatus.failure, showCodeError: true));
      emit(state.copyWith(status: VerifyEmailStatus.initial));
      return;
    }
    emit(state.copyWith(status: VerifyEmailStatus.inProgress));
    // PROVISIONAL: sin endpoint todavía.
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (isClosed) return;
    emit(state.copyWith(status: VerifyEmailStatus.success));
  }

  Future<void> resend() async {
    if (!state.canResend) return;
    emit(state.copyWith(isResending: true));
    // PROVISIONAL: sin endpoint todavía.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (isClosed) return;
    emit(
      state.copyWith(
        isResending: false,
        resendCooldown: 60,
        resendTick: state.resendTick + 1,
      ),
    );
    _startCooldown();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isClosed) {
        timer.cancel();
        return;
      }
      if (state.resendCooldown <= 1) {
        emit(state.copyWith(resendCooldown: 0));
        timer.cancel();
      } else {
        emit(state.copyWith(resendCooldown: state.resendCooldown - 1));
      }
    });
  }

  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    return super.close();
  }
}
```

---

## 6. VerifyEmailFormFields

**Ruta:** `lib/features/auth/presentation/widgets/verify_email_form_fields.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../l10n/app_localizations.dart';
import '../cubit/verify_email_cubit.dart';
import '../cubit/verify_email_state.dart';
import 'custom_text_field.dart';

/// SOLID (SRP): el campo de código vive aquí — la pantalla solo orquesta
/// (bloc-patterns: sin BlocBuilder de campos inline).
class VerifyEmailFormFields extends StatelessWidget {
  const VerifyEmailFormFields({
    super.key,
    required this.codeController,
    required this.codeFocus,
    required this.onSubmit,
  });

  final TextEditingController codeController;
  final FocusNode codeFocus;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<VerifyEmailCubit, VerifyEmailState>(
      buildWhen: (p, c) => p.code != c.code || p.showCodeError != c.showCodeError,
      builder: (context, state) {
        return CustomTextField(
          key: const ValueKey('verify_email_code'),
          label: l10n.verifyEmailCodeLabel,
          controller: codeController,
          focusNode: codeFocus,
          hintText: l10n.verifyEmailCodeHint,
          prefixIcon: const Icon(Icons.pin_outlined),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          errorText: switch (state.codeErrorKey()) {
            'empty' => l10n.verifyEmailCodeRequired,
            'invalid' => l10n.verifyEmailCodeInvalid,
            _ => null,
          },
          onChanged: (v) => context.read<VerifyEmailCubit>().codeChanged(v),
          onFieldSubmitted: (_) => onSubmit(),
        );
      },
    );
  }
}
```

---

## 7. VerifyEmailScreen

**Ruta:** `lib/features/auth/presentation/screens/verify_email_screen.dart`

Incluye botón de volver explícito (flecha arriba-izquierda) **y** manejo del
back nativo de Android (gesto/botón del sistema) — como la ruta se llega
vía `context.go()` (reemplaza el stack, no hay nada que "popear"), sin esto
el back del sistema no haría nada útil. Ambos caminos van a `/login`
(`PopScope` + `onPopInvokedWithResult`, API vigente en Flutter 3.47).
MVP solo Android por ahora (anotado — `flutter-architecture` ya lista
Android+iOS como destino final, pero el primer release es Android).

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/routes/auth_guard.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
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
  late final TextEditingController _code = TextEditingController();
  late final FocusNode _codeFocus = FocusNode();

  @override
  void dispose() {
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<VerifyEmailCubit>().submit();
  }

  void _backToLogin() => context.go(AuthGuard.loginRoute);

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
          child: BlocListener<VerifyEmailCubit, VerifyEmailState>(
            listenWhen: (prev, curr) =>
                prev.status != curr.status || prev.resendTick != curr.resendTick,
            listener: (context, state) {
              if (state.status == VerifyEmailStatus.success) {
                TextInput.finishAutofillContext();
                AppToast.success(context, l10n.verifyEmailDemoSuccess);
              } else if (state.status == VerifyEmailStatus.failure) {
                _codeFocus.requestFocus();
                AppToast.error(context, l10n.verifyEmailFormInvalid);
              } else if (state.resendTick > 0) {
                AppToast.success(context, l10n.verifyEmailResendSuccess);
              }
            },
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: l10n.commonBack,
                        onPressed: _backToLogin,
                      ),
                    ),
                    Icon(
                      Icons.mark_email_unread_outlined,
                      size: 80,
                      color: theme.colorScheme.primary,
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
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 32),
                    VerifyEmailFormFields(
                      codeController: _code,
                      codeFocus: _codeFocus,
                      onSubmit: _submit,
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<VerifyEmailCubit, VerifyEmailState>(
                      buildWhen: (p, c) => p.status != c.status,
                      builder: (context, state) {
                        if (state.isInProgress) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submit,
                            child: Text(l10n.verifyEmailButton),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    BlocBuilder<VerifyEmailCubit, VerifyEmailState>(
                      buildWhen: (p, c) =>
                          p.resendCooldown != c.resendCooldown ||
                          p.isResending != c.isResending,
                      builder: (context, state) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.verifyEmailResendQuestion,
                              style: theme.textTheme.bodyMedium,
                            ),
                            TextButton(
                              onPressed: state.canResend
                                  ? () => context.read<VerifyEmailCubit>().resend()
                                  : null,
                              child: Text(
                                state.resendCooldown > 0
                                    ? l10n.verifyEmailResendIn(state.resendCooldown)
                                    : l10n.verifyEmailResend,
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
        ),
      ),
    );
  }
}
```

---

## 8. setup_di.dart (fragmento nuevo)

**Ruta:** `lib/core/di/setup_di.dart`

Agregar (sección `--- Cubits ---`, junto a `LoginCubit`):

```dart
  locator.registerFactoryParam<VerifyEmailCubit, String, void>(
    (email, _) => VerifyEmailCubit(email: email),
  );
```

(import `../../features/auth/presentation/cubit/verify_email_cubit.dart`)

---

## 9. app_router.dart (fragmento nuevo)

**Ruta:** `lib/core/routes/app_router.dart`

Agregar un `GoRoute` más dentro de `routes:`:

```dart
      GoRoute(
        path: AuthGuard.verifyEmailRoute,
        pageBuilder: (context, state) => CustomTransitions.slideUp(
          state,
          VerifyEmailScreen(email: (state.extra as String?) ?? ''),
        ),
      ),
```

(import `'../../features/auth/presentation/screens/verify_email_screen.dart'`)

---

## 10. splash_screen.dart — cambio TEMPORAL solo para que la veas

**Ruta:** `lib/core/screens/splash_screen.dart`

**Antes:**
```dart
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) context.go(AuthGuard.loginRoute);
```

**Después (temporal — se revierte apenas apruebes la pantalla):**
```dart
    await Future<void>.delayed(const Duration(milliseconds: 800));
    // TEMPORAL (propuesta 005): apunta a /verify-email solo para previsualizar
    // la pantalla nueva — se revierte a loginRoute al aprobarla.
    if (mounted) {
      context.go(AuthGuard.verifyEmailRoute, extra: 'correo@ejemplo.com');
    }
```

---

## 11. login_screen.dart (actualización — SnackBar → Toast)

**Ruta:** `lib/features/auth/presentation/screens/login_screen.dart`

**Antes:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../l10n/app_localizations.dart';
```
```dart
            } else if (state.status == LoginStatus.failure) {
              // Foco al primer campo inválido en orden visual (forms skill).
              if (state.email.isNotValid) {
                _emailFocus.requestFocus();
              } else {
                _passwordFocus.requestFocus();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.loginFormInvalid),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            }
```

**Después:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../l10n/app_localizations.dart';
```
```dart
            } else if (state.status == LoginStatus.failure) {
              // Foco al primer campo inválido en orden visual (forms skill).
              if (state.email.isNotValid) {
                _emailFocus.requestFocus();
              } else {
                _passwordFocus.requestFocus();
              }
              AppToast.error(context, l10n.loginFormInvalid);
            }
```

(la variable `theme` sigue usándose más abajo en el `build` — no se elimina del método, solo deja de pasarse al SnackBar)

---

## 12. app_es.arb (fragmento nuevo)

**Ruta:** `lib/l10n/app_es.arb`

Agregar:

```json
  "commonBack": "Volver",
  "verifyEmailHeadline": "Verifica tu correo",
  "verifyEmailSubtitle": "Enviamos un código de 6 dígitos a {email}",
  "@verifyEmailSubtitle": {
    "placeholders": { "email": { "type": "String" } }
  },
  "verifyEmailCodeLabel": "Código de verificación",
  "verifyEmailCodeHint": "000000",
  "verifyEmailCodeRequired": "Ingresa el código que te enviamos",
  "verifyEmailCodeInvalid": "El código debe tener 6 dígitos",
  "verifyEmailButton": "Verificar",
  "verifyEmailFormInvalid": "Revisa el código ingresado",
  "verifyEmailResendQuestion": "¿No recibiste el código? ",
  "verifyEmailResend": "Reenviar",
  "verifyEmailResendIn": "Reenviar en {seconds}s",
  "@verifyEmailResendIn": {
    "placeholders": { "seconds": { "type": "int" } }
  },
  "verifyEmailResendSuccess": "Código reenviado — revisa tu correo",
  "verifyEmailDemoSuccess": "Verificación simulada — sin backend todavía"
```

Ejecutar `flutter gen-l10n` después.

---

## Orden de aplicación

1. `lib/core/widgets/app_toast.dart`
2. `lib/features/auth/presentation/widgets/custom_text_field.dart` (actualizar)
3. `lib/features/auth/presentation/inputs/verify_email_inputs.dart`
4. `lib/features/auth/presentation/cubit/verify_email_state.dart`
5. `lib/features/auth/presentation/cubit/verify_email_cubit.dart`
6. `lib/features/auth/presentation/widgets/verify_email_form_fields.dart`
7. `lib/features/auth/presentation/screens/verify_email_screen.dart`
8. `lib/l10n/app_es.arb` (actualizar) + `flutter gen-l10n`
9. `lib/core/di/setup_di.dart` (actualizar)
10. `lib/core/routes/app_router.dart` (actualizar)
11. `lib/core/screens/splash_screen.dart` (cambio temporal de QA)
12. `lib/features/auth/presentation/screens/login_screen.dart` (actualizar)
13. `flutter analyze` + `flutter test` (sanity del implementador; la
    verificación completa y el commit esperan tu aprobación visual)
14. Mostrar en el emulador → **tu aprobación** → revertir el paso 11 a
    `AuthGuard.loginRoute` → recién ahí se retoma la propuesta 004
