# Propuesta: LoginScreen — capa de presentación (sin conectar)

Primera pantalla de la feature auth. Solo `presentation/` con cubit mock
(estados visuales reales: validación de formulario, loading, error local),
sin `domain/` ni `data/` — la integración `/auth/login` va en la siguiente
propuesta (screen-first-workflow). Referencia visual aprobada: mock con
imagotipo Depredadog, headline "VUELVE A LA MANADA", campos con label
externo, botón ketchup + acento mostaza, Google outlined y link de registro.

**MVP: solo modo claro** — el modo oscuro queda pendiente (pendientes).

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/presentation/inputs/login_inputs.dart` | nuevo — inputs Formz (email/password) |
| `lib/features/auth/presentation/cubit/login_state.dart` | nuevo — estado con inputs + status + obscure |
| `lib/features/auth/presentation/cubit/login_cubit.dart` | nuevo — cubit mock con validación real y submit simulado |
| `lib/features/auth/presentation/widgets/custom_text_field.dart` | nuevo — campo con label externo + iconos + error |
| `lib/features/auth/presentation/widgets/login_brand_header.dart` | nuevo — imagotipo + headline + subtítulo |
| `lib/features/auth/presentation/widgets/google_sign_in_button.dart` | nuevo — OutlinedButton con logo G (PROVISIONAL, sin endpoint) |
| `lib/features/auth/presentation/screens/login_screen.dart` | nuevo — LoginScreen + _LoginView |
| `lib/core/screens/home_placeholder_screen.dart` | nuevo — placeholder provisional de /home |
| `lib/core/routes/app_router.dart` | actualizar — quita /welcome, agrega /login con slideUp |
| `lib/core/routes/auth_guard.dart` | actualizar — quita welcomeRoute, redirect → /login |
| `lib/core/screens/splash_screen.dart` | actualizar — navega a /login (welcome eliminado) |
| `lib/core/screens/welcome_screen.dart` | **eliminar** — el proyecto no tendrá pantalla welcome |
| `lib/core/di/setup_di.dart` | actualizar — registerFactory LoginCubit |
| `lib/core/theme/app_theme.dart` | actualizar — inputDecorationTheme (relleno, radio, error) |
| `lib/l10n/app_es.arb` | actualizar — claves del login |
| `pubspec.yaml` | actualizar — sección `assets:` |
| `assets/images/` | nuevos — `imagotipo_depredadog.png` (+2x/3x/4x) y `google_g.png` |

---

## 1. login_inputs.dart (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/inputs/login_inputs.dart`

```dart
import 'package:formz/formz.dart';

/// SOLID (SRP): cada input conoce su propia regla de validación — la UI solo
/// lee `displayError`, nunca valida en el widget.
enum EmailValidationError { invalid, empty }

final class EmailInput extends FormzInput<String, EmailValidationError> {
  const EmailInput.pure() : super.pure('');
  const EmailInput.dirty([super.value = '']) : super.dirty();

  static final _regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  EmailValidationError? validator(String value) {
    if (value.trim().isEmpty) return EmailValidationError.empty;
    if (!_regex.hasMatch(value.trim())) return EmailValidationError.invalid;
    return null;
  }
}

enum PasswordValidationError { empty, tooShort }

final class PasswordInput extends FormzInput<String, PasswordValidationError> {
  const PasswordInput.pure() : super.pure('');
  const PasswordInput.dirty([super.value = '']) : super.dirty();

  @override
  PasswordValidationError? validator(String value) {
    if (value.isEmpty) return PasswordValidationError.empty;
    if (value.length < 6) return PasswordValidationError.tooShort;
    return null;
  }
}
```

## 2. login_state.dart (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/cubit/login_state.dart`

```dart
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../inputs/login_inputs.dart';

enum LoginStatus { initial, inProgress, success, failure }

/// Estado de la pantalla de login. `showErrors` se activa al primer submit
/// para que los errores solo aparezcan tras intentar entrar
/// (AutovalidateMode.onUserInteraction por estado, no por el widget).
class LoginState extends Equatable {
  const LoginState({
    this.email = const EmailInput.pure(),
    this.password = const PasswordInput.pure(),
    this.obscurePassword = true,
    this.status = LoginStatus.initial,
    this.showErrors = false,
  });

  final EmailInput email;
  final PasswordInput password;
  final bool obscurePassword;
  final LoginStatus status;
  final bool showErrors;

  bool get isValid => Formz.validate([email, password]);
  bool get isInProgress => status == LoginStatus.inProgress;

  LoginState copyWith({
    EmailInput? email,
    PasswordInput? password,
    bool? obscurePassword,
    LoginStatus? status,
    bool? showErrors,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      status: status ?? this.status,
      showErrors: showErrors ?? this.showErrors,
    );
  }

  @override
  List<Object?> get props =>
      [email, password, obscurePassword, status, showErrors];
}
```

## 3. login_cubit.dart (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/cubit/login_cubit.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../inputs/login_inputs.dart';
import 'login_state.dart';

/// PROVISIONAL (fase presentación): el submit simula la llamada al backend
/// con un delay y emite `success` — la integración real de /auth/login
/// reemplaza este método en la propuesta de integración.
class LoginCubit extends Cubit<LoginState> {
  LoginCubit() : super(const LoginState());

  void emailChanged(String value) =>
      emit(state.copyWith(email: EmailInput.dirty(value)));

  void passwordChanged(String value) =>
      emit(state.copyWith(password: PasswordInput.dirty(value)));

  void togglePasswordVisibility() =>
      emit(state.copyWith(obscurePassword: !state.obscurePassword));

  Future<void> submit() async {
    if (!state.isValid) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    emit(state.copyWith(status: LoginStatus.inProgress));
    // PROVISIONAL: sin endpoint todavía — delay para mostrar el loading.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    emit(state.copyWith(status: LoginStatus.success));
  }
}
```

## 4. custom_text_field.dart (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/widgets/custom_text_field.dart`

```dart
import 'package:flutter/material.dart';

/// SOLID (SRP): campo de formulario del proyecto — label externo arriba,
/// icono prefijo, error reservado abajo (helperText ' ' para que el error
/// no re-fluje el formulario — flutter-building-forms regla 9).
class CustomTextField extends StatelessWidget {
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
    this.trailing, // ej. link "¿Olvidaste tu contraseña?" en la fila del label
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
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          // Reserva espacio: errorText o helper ' ' ocupan la misma línea.
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            errorText: errorText,
            helperText: ' ',
            errorStyle: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ),
      ],
    );
  }
}
```

## 5. login_brand_header.dart (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/widgets/login_brand_header.dart`

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Encabezado de marca del login: imagotipo vertical Depredadog
/// (versión positiva para fondo claro) + headline + subtítulo.
class LoginBrandHeader extends StatelessWidget {
  const LoginBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      children: [
        Image.asset(
          'assets/images/imagotipo_depredadog.png',
          height: 148,
          fit: BoxFit.contain,
          semanticLabel: l10n.appName,
        ),
        const SizedBox(height: 24),
        Text(
          l10n.loginHeadline,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.loginSubtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
```

## 6. google_sign_in_button.dart (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/widgets/google_sign_in_button.dart`

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// PROVISIONAL: botón de Google sin endpoint — muestra un aviso hasta que
/// /auth/google se integre (client IDs pendientes — ver propuesta de
/// integración correspondiente).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.comingSoon)),
          );
        },
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/google_g.png', height: 20, width: 20),
            const SizedBox(width: 12),
            Text(l10n.loginGoogleButton),
          ],
        ),
      ),
    );
  }
}
```

## 7. login_screen.dart (archivo nuevo)

**Ruta:** `lib/features/auth/presentation/screens/login_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/setup_di.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/login_brand_header.dart';

/// Pantalla de login — primera de la feature auth (fase presentación).
/// Patrón dos clases: `LoginScreen` provee el cubit local vía locator,
/// `_LoginView` renderiza.
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.loginDemoSuccess)),
              );
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
                    BlocBuilder<LoginCubit, LoginState>(
                      buildWhen: (p, c) =>
                          p.email != c.email || p.showErrors != c.showErrors,
                      builder: (context, state) {
                        return CustomTextField(
                          label: l10n.loginEmailLabel,
                          controller: _email,
                          focusNode: _emailFocus,
                          hintText: l10n.loginEmailHint,
                          prefixIcon: const Icon(Icons.mail_outline),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          errorText: state.showErrors && state.email.isNotValid
                              ? l10n.loginEmailError
                              : null,
                          onChanged: (v) =>
                              context.read<LoginCubit>().emailChanged(v),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    BlocBuilder<LoginCubit, LoginState>(
                      buildWhen: (p, c) =>
                          p.password != c.password ||
                          p.obscurePassword != c.obscurePassword ||
                          p.showErrors != c.showErrors,
                      builder: (context, state) {
                        return CustomTextField(
                          label: l10n.loginPasswordLabel,
                          controller: _password,
                          focusNode: _passwordFocus,
                          obscureText: state.obscurePassword,
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
                            onPressed: () => context
                                .read<LoginCubit>()
                                .togglePasswordVisibility(),
                          ),
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          errorText:
                              state.showErrors && state.password.isNotValid
                                  ? l10n.loginPasswordError
                                  : null,
                          onChanged: (v) =>
                              context.read<LoginCubit>().passwordChanged(v),
                          onFieldSubmitted: (_) => _submit(),
                          trailing: GestureDetector(
                            onTap: () {
                              // PROVISIONAL: /forgot-password llega en su
                              // propia pantalla — por ahora aviso.
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
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<LoginCubit, LoginState>(
                      buildWhen: (p, c) => p.status != c.status,
                      builder: (context, state) {
                        if (state.isInProgress) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return ElevatedButton(
                          onPressed: _submit,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(l10n.loginButton),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.pets,
                                size: 16,
                                color: theme.colorScheme.secondary,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                            // PROVISIONAL: /register llega en su propia
                            // pantalla — por ahora aviso.
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.comingSoon)),
                            );
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

## 8. home_placeholder_screen.dart (archivo nuevo)

**Ruta:** `lib/core/screens/home_placeholder_screen.dart`

```dart
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// PROVISIONAL: destino de /home hasta que la feature home exista.
/// Hoy es inalcanzable (AuthGuard exige sesión y isAuthenticated=false).
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Text('${l10n.appName} — ${l10n.comingSoon}'),
      ),
    );
  }
}
```

## 9. app_router.dart (archivo existente — actualización)

**Ruta:** `lib/core/routes/app_router.dart`

**Antes:**
```dart
import 'package:go_router/go_router.dart';

import '../screens/splash_screen.dart';
import '../screens/welcome_screen.dart';
import 'auth_guard.dart';
import 'custom_transitions.dart';
```

**Después:**
```dart
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../screens/home_placeholder_screen.dart';
import '../screens/splash_screen.dart';
import 'auth_guard.dart';
import 'custom_transitions.dart';
```

**Antes:**
```dart
      GoRoute(
        path: AuthGuard.welcomeRoute,
        pageBuilder: (context, state) =>
            CustomTransitions.fade(state, const WelcomeScreen()),
      ),
      // /home es el destino autenticado — pantalla real llega con las
      // features; por ahora el guard bloquea el acceso sin sesión.
      // PROVISIONAL: placeholder hasta que 003-app-auth defina el shell.
      GoRoute(
        path: AuthGuard.homeRoute,
        pageBuilder: (context, state) =>
            CustomTransitions.fade(state, const WelcomeScreen()),
      ),
      // Las rutas /login, /register, /verify-email, /forgot-password y
      // /reset-password se registran en la propuesta 003-app-auth — el
      // guard ya las trata como públicas.
    ],
```

**Después:**
```dart
      // /home es el destino autenticado — pantalla real llega con las
      // features; por ahora el guard bloquea el acceso sin sesión.
      // PROVISIONAL: placeholder hasta que exista el shell autenticado.
      GoRoute(
        path: AuthGuard.homeRoute,
        pageBuilder: (context, state) =>
            CustomTransitions.fade(state, const HomePlaceholderScreen()),
      ),
      GoRoute(
        path: AuthGuard.loginRoute,
        pageBuilder: (context, state) =>
            CustomTransitions.slideUp(state, const LoginScreen()),
      ),
      // /register, /verify-email, /forgot-password y /reset-password se
      // registran con cada pantalla — el guard ya las trata como públicas.
    ],
```

## 10. auth_guard.dart (archivo existente — actualización)

**Ruta:** `lib/core/routes/auth_guard.dart`

**Antes:**
```dart
  static const String splashRoute = '/';
  static const String welcomeRoute = '/welcome';
  static const String homeRoute = '/home';

  // Rutas de la feature auth (002) — declaradas ya para que el guard las
  // conozca; se registran en app_router cuando existan sus pantallas.
```

**Después:**
```dart
  static const String splashRoute = '/';
  static const String homeRoute = '/home';

  // Rutas de la feature auth — declaradas ya para que el guard las
  // conozca; se registran en app_router cuando existan sus pantallas.
```

**Antes:**
```dart
  static const Set<String> defaultPublicRoutes = {
    splashRoute,
    welcomeRoute,
    loginRoute,
```

**Después:**
```dart
  static const Set<String> defaultPublicRoutes = {
    splashRoute,
    loginRoute,
```

**Antes:**
```dart
  /// A dónde mandar a un usuario sin sesión que pide una ruta protegida.
  static const String unauthenticatedRedirect = welcomeRoute;
```

**Después:**
```dart
  /// A dónde mandar a un usuario sin sesión que pide una ruta protegida.
  static const String unauthenticatedRedirect = loginRoute;
```

## 11. splash_screen.dart (archivo existente — actualización)

**Ruta:** `lib/core/screens/splash_screen.dart`

**Antes:**
```dart
/// Splash de marca: flama + nombre + tagline. Tras ~1.2s navega según el
/// estado de sesión (el guard decide — sin sesión cae en /welcome).
```

**Después:**
```dart
/// Splash de marca: flama + nombre + tagline. Tras ~1.2s navega al login
/// (sin sesión — el guard redirige las rutas protegidas igualmente).
```

**Antes:**
```dart
      if (mounted) context.go(AuthGuard.welcomeRoute);
```

**Después:**
```dart
      if (mounted) context.go(AuthGuard.loginRoute);
```

## 12. welcome_screen.dart — ELIMINAR

**Ruta:** `lib/core/screens/welcome_screen.dart`

Borrar el archivo completo — el proyecto no tendrá pantalla welcome
(decisión del usuario). Sus claves ARB se eliminan en el paso 14.

## 13. setup_di.dart (archivo existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

Agregar import de `LoginCubit` y, antes de la sección `--- Router ---`:

**Después:**
```dart
  // --- Cubits ---
  // PROVISIONAL (presentación): sin use cases reales todavía.
  locator.registerFactory<LoginCubit>(() => LoginCubit());

  // --- Router ---
```

## 14. app_theme.dart (archivo existente — actualización)

**Ruta:** `lib/core/theme/app_theme.dart`

**Antes:**
```dart
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
```

**Después:**
```dart
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
```

## 15. app_es.arb (archivo existente — actualización)

**Ruta:** `lib/l10n/app_es.arb`

Eliminar las claves del welcome (`welcomeTitle`, `welcomeBody`,
`welcomeAuthPending`) y agregar al final (antes del cierre):

```json
  "loginHeadline": "VUELVE A LA MANADA",
  "loginSubtitle": "Inicia sesión para pedir algo salvajemente bueno.",
  "loginEmailLabel": "Correo electrónico",
  "loginEmailHint": "nombre@correo",
  "loginEmailError": "Ingresa un correo válido",
  "loginPasswordLabel": "Contraseña",
  "loginPasswordError": "Mínimo 6 caracteres",
  "loginShowPassword": "Mostrar contraseña",
  "loginHidePassword": "Ocultar contraseña",
  "loginForgotPassword": "¿Olvidaste tu contraseña?",
  "loginButton": "Iniciar sesión",
  "loginOrContinueWith": "o continúa con",
  "loginGoogleButton": "Ingresar con Google",
  "loginNoAccount": "¿No tienes cuenta? ",
  "loginRegisterLink": "Regístrate",
  "loginDemoSuccess": "Inicio de sesión simulado — sin backend todavía",
  "comingSoon": "Disponible próximamente"
```

## 16. pubspec.yaml (archivo existente — actualización)

Agregar bajo `uses-material-design: true`:

```yaml
  assets:
    - assets/images/
```

## 17. Assets (paso manual del implementador)

- Copiar `Design/brand/png/{1x,1.5x,2x,3x,4x}/imagotipo_negro*` a:
  - `assets/images/imagotipo_depredadog.png` (mdpi/1x)
  - `assets/images/1.5x/imagotipo_depredadog.png`
  - `assets/images/2.0x/imagotipo_depredadog.png`
  - `assets/images/3.0x/imagotipo_depredadog.png`
  - `assets/images/4.0x/imagotipo_depredadog.png`
- Descargar el logo oficial de Google ("G" multicolor, ~48px) a
  `assets/images/google_g.png`. Si no se puede descargar, fallback
  provisional `Icon(Icons.g_mobiledata)`.

---

## Pasos adicionales

1. Ejecutar `flutter gen-l10n` tras actualizar `app_es.arb`.
2. `flutter analyze` + `flutter test` (screen test del login: campos,
   botones, estados de error visibles — ver testing-workflow).
3. Dejar la app corriendo en el emulador para **aprobación visual**.
4. Tras el OK visual: registrar spec del login en `design-system.yaml`
   (design-system-docs) y correr auditoría.
5. PROVISIONAL marcados: submit sin endpoint, Google button, link
   forgot-password, modo oscuro (MVP solo claro).

## Orden de aplicación

1. Assets + pubspec → 2. ARB + gen-l10n → 3. inputs/state/cubit →
4. widgets → 5. screen → 6. theme/DI/router/welcome → 7. verify.
