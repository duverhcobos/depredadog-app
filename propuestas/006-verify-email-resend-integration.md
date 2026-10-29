# Propuesta 006: Integración `/auth/verify-email` + `/auth/resend-verification`

Segundo y tercer endpoints reales de la feature auth (fase 2 del `screen-first-workflow`,
un ciclo por pantalla — los dos endpoints viven en la misma `VerifyEmailScreen`,
aprobada visualmente en propuesta 005).

**Hechos del contrato backend (verificados contra el código NestJS):**

- `POST /auth/verify-email` (`@Throttle 5/min`, público): body
  `{ email, code, deviceFingerprint?, platform? }` — `code` valida `^\d{6}$`.
  **Éxito devuelve `IssuedSession` = `{ accessToken, refreshToken, user }`
  (idéntico a `/auth/login`) → verificar ES auto-login.** Errores: 400
  `Invalid or expired code` (mismo mensaje para código errado, expirado o
  cuenta ya verificada / inexistente — anti-enumeración), 400 de validación
  de DTO, 429 rate limit.
- `POST /auth/resend-verification` (`@Throttle 3/min`, público): body
  `{ email }` → 200 siempre (silencio total si el correo no existe o ya
  está verificado — anti-enumeración).
- Dev sin `RESEND_API_KEY`: el código cae al log del backend (fallback ya
  implementado) — la verificación manual lee el código de ahí.

**Decisiones embebidas (a confirmar en la encuesta):**

| Decisión | Propuesta |
|---|---|
| Destino post-verificación | **`/home` directo (auto-login)** — el backend emite sesión; re-pedir password sería redundante (y dispararía el modal de Google sin necesidad) |
| Código errado/expirado (400) | **Casillas en rojo + toast + refocus al OTP** (mismo patrón de error por campo del formulario) |
| Resend con fallo | **El código tipeado se conserva** — el código viejo sigue válido en el server (el reenvío falló, no se emitió uno nuevo); solo se limpia en reenvío exitoso |
| Errores 429 / sin red / desconocido | **Reuso de las claves `loginError*`** (mismos textos: "Demasiados intentos", "Sin conexión", "Ocurrió un error") — solo se agrega `verifyEmailErrorInvalidCode` |

Errores de resend reusan el mismo `status: authError` + `authFailure` del
estado (mismo mecanismo que login §004) — el listener mapea AuthFailure →
texto una sola vez; `InvalidCodeFailure` solo llega por verificación así
que el refocus al OTP no aplica falsamente a errores de reenvío.

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/domain/failures/auth_failure.dart` | Actualizar — nuevo `InvalidCodeFailure` |
| `lib/features/auth/domain/repositories/i_auth_repository.dart` | Actualizar — `verifyEmail` + `resendVerification` |
| `lib/features/auth/domain/use_cases/verify_email_use_case.dart` | **Nuevo** |
| `lib/features/auth/domain/use_cases/resend_verification_use_case.dart` | **Nuevo** |
| `lib/features/auth/data/datasources/interfaces/i_auth_remote_datasource.dart` | Actualizar — 2 métodos |
| `lib/features/auth/data/datasources/implementations/auth_remote_datasource_impl.dart` | Actualizar — 2 métodos |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | Actualizar — 2 métodos + mapping 400 |
| `lib/features/auth/presentation/cubit/verify_email_state.dart` | Actualizar — status `authError` + `authFailure` |
| `lib/features/auth/presentation/cubit/verify_email_cubit.dart` | Actualizar — `submit`/`resend` reales + `AuthSession` |
| `lib/features/auth/presentation/widgets/verify_email_form_fields.dart` | Actualizar — `hasError` incluye `InvalidCodeFailure`; `buildWhen` escucha `authFailure` |
| `lib/features/auth/presentation/screens/verify_email_screen.dart` | Actualizar — éxito → `/home`; authError → toast mapeado |
| `lib/core/di/setup_di.dart` | Actualizar — registrar use cases + deps del cubit |
| `lib/l10n/app_es.arb` + `flutter gen-l10n` | +`verifyEmailErrorInvalidCode`; −`verifyEmailDemoSuccess` (ya no hay simulado) |
| `test/features/auth/presentation/screens/verify_email_screen_test.dart` | Actualizar — registrar mocks de los use cases |
| `test/features/auth/presentation/cubit/verify_email_cubit_test.dart` | **Nuevo** |
| `test/features/auth/data/repositories/auth_repository_impl_test.dart` | Extender — mapping verify/resend |

---

## 1. `auth_failure.dart` (existente — actualización)

**Ruta:** `lib/features/auth/domain/failures/auth_failure.dart`

**Antes:**

```dart
/// 403 — cuenta suspendida por un administrador.
class AccountSuspendedFailure extends AuthFailure {
  const AccountSuspendedFailure();
}
```

**Después:**

```dart
/// 403 — cuenta suspendida por un administrador.
class AccountSuspendedFailure extends AuthFailure {
  const AccountSuspendedFailure();
}

/// 400 en /auth/verify-email — código errado, expirado o cuenta que ya no
/// está pendiente (el backend da el mismo mensaje a todos — anti-enumeración).
class InvalidCodeFailure extends AuthFailure {
  const InvalidCodeFailure();
}
```

## 2. `i_auth_repository.dart` (existente — actualización)

**Ruta:** `lib/features/auth/domain/repositories/i_auth_repository.dart`

**Antes:**

```dart
  Future<Either<AuthFailure, User>> login({
    required String email,
    required String password,
  });
}
```

**Después:**

```dart
  Future<Either<AuthFailure, User>> login({
    required String email,
    required String password,
  });

  /// Verifica el correo con el código de 6 dígitos. Éxito = sesión ya
  /// persistida (el backend emite IssuedSession igual que login).
  Future<Either<AuthFailure, User>> verifyEmail({
    required String email,
    required String code,
  });

  /// Reenvía el código. El backend responde 200 siempre (anti-enumeración).
  Future<Either<AuthFailure, void>> resendVerification({
    required String email,
  });
}
```

## 3. `verify_email_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/domain/use_cases/verify_email_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// SOLID (SRP): un caso de uso por operación — verifica el correo con el
/// código de 6 dígitos. El éxito ya deja la sesión persistida por el
/// repositorio (auto-login — el backend emite IssuedSession igual que
/// /auth/login); el caller solo decide la navegación.
class VerifyEmailUseCase {
  const VerifyEmailUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Either<AuthFailure, User>> call({
    required String email,
    required String code,
  }) => _repository.verifyEmail(email: email, code: code);
}
```

## 4. `resend_verification_use_case.dart` (archivo nuevo)

**Ruta:** `lib/features/auth/domain/use_cases/resend_verification_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// SOLID (SRP): reenvía el código de verificación. El backend responde 200
/// siempre que el body valide (anti-enumeración — silencio si el correo no
/// existe o ya está verificado); los únicos errores posibles son 400 de
/// DTO, 429 y de red.
class ResendVerificationUseCase {
  const ResendVerificationUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Either<AuthFailure, void>> call({required String email}) =>
      _repository.resendVerification(email: email);
}
```

## 5. `i_auth_remote_datasource.dart` (existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/interfaces/i_auth_remote_datasource.dart`

**Antes:**

```dart
abstract class IAuthRemoteDataSource {
  Future<LoginResult> login({
    required String email,
    required String password,
    String? deviceFingerprint,
    String? platform,
  });
}
```

**Después:**

```dart
abstract class IAuthRemoteDataSource {
  Future<LoginResult> login({
    required String email,
    required String password,
    String? deviceFingerprint,
    String? platform,
  });

  /// /auth/verify-email devuelve la misma IssuedSession que login —
  /// se reutiliza LoginResult.
  Future<LoginResult> verifyEmail({
    required String email,
    required String code,
    String? deviceFingerprint,
    String? platform,
  });

  Future<void> resendVerification({required String email});
}
```

## 6. `auth_remote_datasource_impl.dart` (existente — actualización)

**Ruta:** `lib/features/auth/data/datasources/implementations/auth_remote_datasource_impl.dart`

**Antes** (cierre de la clase):

```dart
    return LoginResult(
      accessToken: map['accessToken'] as String,
      refreshToken: map['refreshToken'] as String,
      user: UserModel.fromJson(map['user'] as Map<String, dynamic>),
    );
  }
}
```

**Después:**

```dart
    return LoginResult(
      accessToken: map['accessToken'] as String,
      refreshToken: map['refreshToken'] as String,
      user: UserModel.fromJson(map['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<LoginResult> verifyEmail({
    required String email,
    required String code,
    String? deviceFingerprint,
    String? platform,
  }) async {
    final response = await _networkService.post(
      '/auth/verify-email',
      body: {
        'email': email,
        'code': code,
        'deviceFingerprint': ?deviceFingerprint,
        'platform': ?platform,
      },
    );
    final map = response as Map<String, dynamic>;
    return LoginResult(
      accessToken: map['accessToken'] as String,
      refreshToken: map['refreshToken'] as String,
      user: UserModel.fromJson(map['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<void> resendVerification({required String email}) {
    return _networkService.post(
      '/auth/resend-verification',
      body: {'email': email},
    );
  }
}
```

## 7. `auth_repository_impl.dart` (existente — actualización)

**Ruta:** `lib/features/auth/data/repositories/auth_repository_impl.dart`

**Antes:**

```dart
  AuthFailure _mapFailure(NetworkException e) {
    if (e is NoConnectionException) return const NoConnectionFailure();
    // 401 en /auth/login solo significa credenciales inválidas (no sesión
    // expirada — este repositorio nunca llama endpoints autenticados).
    if (e is UnauthorizedException) return const InvalidCredentialsFailure();
    if (e.statusCode == 403) {
```

**Después:**

```dart
  @override
  Future<Either<AuthFailure, User>> verifyEmail({
    required String email,
    required String code,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NoConnectionFailure());
    }
    try {
      final fingerprint = await _deviceInfoProvider.fingerprint();
      final result = await _remoteDataSource.verifyEmail(
        email: email,
        code: code,
        deviceFingerprint: fingerprint,
        platform: _deviceInfoProvider.platform,
      );
      await _localDataSource.saveSession(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      return Right(result.user);
    } on NetworkException catch (e) {
      return Left(_mapFailure(e));
    } catch (e) {
      return Left(UnknownAuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<AuthFailure, void>> resendVerification({
    required String email,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NoConnectionFailure());
    }
    try {
      await _remoteDataSource.resendVerification(email: email);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(_mapFailure(e));
    } catch (e) {
      return Left(UnknownAuthFailure(e.toString()));
    }
  }

  AuthFailure _mapFailure(NetworkException e) {
    if (e is NoConnectionException) return const NoConnectionFailure();
    // 401 en /auth/login solo significa credenciales inválidas (no sesión
    // expirada — este repositorio nunca llama endpoints autenticados).
    if (e is UnauthorizedException) return const InvalidCredentialsFailure();
    // 400 "Invalid or expired code" cubre código errado, expirado y cuenta
    // no pendiente (el backend no los distingue — anti-enumeración). Otros
    // 400 (validación de DTO) caen a Unknown — la UI ya impide formatos
    // inválidos, así que un 400 ajeno al código es un bug, no un caso UX.
    if (e.statusCode == 400 && e.message == 'Invalid or expired code') {
      return const InvalidCodeFailure();
    }
    if (e.statusCode == 403) {
```

## 8. `verify_email_state.dart` (existente — actualización)

**Ruta:** `lib/features/auth/presentation/cubit/verify_email_state.dart`

**Antes:**

```dart
import 'package:equatable/equatable.dart';

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
```

**Después:**

```dart
import 'package:equatable/equatable.dart';

import '../../domain/failures/auth_failure.dart';
import '../inputs/verify_email_inputs.dart';

/// `failure` = validación local (código vacío/formato) — ya existía.
/// `authError` = el backend rechazó verify o resend (código inválido, rate
/// limit, sin conexión) — trae `authFailure` con el motivo (mismo patrón
/// que LoginState §004).
enum VerifyEmailStatus { initial, inProgress, success, failure, authError }

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
    this.authFailure,
  });
```

Y en `copyWith`, siguiendo el patrón de `LoginState` (solo retiene
`authFailure` cuando el status es `authError`):

```dart
  VerifyEmailState copyWith({
    CodeInput? code,
    VerifyEmailStatus? status,
    bool? showCodeError,
    int? resendCooldown,
    bool? isResending,
    int? resendTick,
    AuthFailure? authFailure,
  }) {
    return VerifyEmailState(
      email: email,
      code: code ?? this.code,
      status: status ?? this.status,
      showCodeError: showCodeError ?? this.showCodeError,
      resendCooldown: resendCooldown ?? this.resendCooldown,
      isResending: isResending ?? this.isResending,
      resendTick: resendTick ?? this.resendTick,
      authFailure: status == VerifyEmailStatus.authError
          ? (authFailure ?? this.authFailure)
          : null,
    );
  }
```

(`props` agrega `authFailure` al final de la lista.)

## 9. `verify_email_cubit.dart` (existente — actualización)

**Ruta:** `lib/features/auth/presentation/cubit/verify_email_cubit.dart`

**Antes:**

```dart
/// PROVISIONAL (fase presentación): submit y reenvío simulados — la
/// integración real de /auth/verify-email y /auth/resend-verification
/// reemplaza estos métodos en sus propios ciclos. El cooldown de reenvío
/// SÍ es real (Timer), no es parte de lo que falta integrar.
class VerifyEmailCubit extends Cubit<VerifyEmailState> {
  VerifyEmailCubit({required String email})
    : super(VerifyEmailState(email: email));

  Timer? _cooldownTimer;

  void codeChanged(String value) =>
      emit(state.copyWith(code: CodeInput.dirty(value), showCodeError: false));

  Future<void> submit() async {
    if (state.isInProgress) return;
    if (!state.code.isValid) {
      emit(
        state.copyWith(status: VerifyEmailStatus.failure, showCodeError: true),
      );
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
    // Se limpia el código viejo + error: ese código quedó invalidado por el
    // nuevo envío (revisor-ui) y el TextField queda en sync vía el listener
    // del widget.
    emit(
      state.copyWith(
        code: const CodeInput.pure(),
        showCodeError: false,
        isResending: true,
      ),
    );
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
```

**Después:**

```dart
/// Integración real de /auth/verify-email + /auth/resend-verification
/// (propuesta 006). El cooldown de reenvío sigue siendo Timer local.
class VerifyEmailCubit extends Cubit<VerifyEmailState> {
  VerifyEmailCubit({
    required String email,
    required VerifyEmailUseCase verifyEmailUseCase,
    required ResendVerificationUseCase resendVerificationUseCase,
    required AuthSession authSession,
  }) : _verifyEmail = verifyEmailUseCase,
       _resendVerification = resendVerificationUseCase,
       _authSession = authSession,
       super(VerifyEmailState(email: email));

  final VerifyEmailUseCase _verifyEmail;
  final ResendVerificationUseCase _resendVerification;
  final AuthSession _authSession;

  Timer? _cooldownTimer;

  void codeChanged(String value) =>
      emit(state.copyWith(code: CodeInput.dirty(value), showCodeError: false));

  Future<void> submit() async {
    if (state.isInProgress) return;
    if (!state.code.isValid) {
      emit(
        state.copyWith(status: VerifyEmailStatus.failure, showCodeError: true),
      );
      emit(state.copyWith(status: VerifyEmailStatus.initial));
      return;
    }
    emit(state.copyWith(status: VerifyEmailStatus.inProgress));
    final result = await _verifyEmail(
      email: state.email,
      code: state.code.value,
    );
    if (isClosed) return;
    result.fold(
      // Las casillas se pintan de error vía hasError del widget
      // (InvalidCodeFailure) — el toast va por el listener del screen.
      (failure) => emit(
        state.copyWith(
          status: VerifyEmailStatus.authError,
          authFailure: failure,
        ),
      ),
      // Verificar emite sesión igual que login: tokens ya persistidos por
      // el repositorio — acá solo marcamos la sesión en memoria (guard →
      // /home) y reportamos éxito.
      (user) {
        _authSession.markAuthenticated();
        emit(state.copyWith(status: VerifyEmailStatus.success));
      },
    );
  }

  Future<void> resend() async {
    if (!state.canResend) return;
    emit(state.copyWith(isResending: true));
    final result = await _resendVerification(email: state.email);
    if (isClosed) return;
    result.fold(
      // Si el reenvío falla el código viejo sigue válido en el server —
      // NO se limpia lo tipeado (solo se limpia cuando sí se reemitió).
      (failure) => emit(
        state.copyWith(
          isResending: false,
          status: VerifyEmailStatus.authError,
          authFailure: failure,
        ),
      ),
      // Se limpia el código viejo + error: quedó invalidado por el nuevo
      // envío (revisor-ui) y el TextField queda en sync vía el listener
      // del widget.
      (_) {
        emit(
          state.copyWith(
            isResending: false,
            code: const CodeInput.pure(),
            showCodeError: false,
            resendCooldown: 60,
            resendTick: state.resendTick + 1,
          ),
        );
        _startCooldown();
      },
    );
  }
```

(`_startCooldown` y `close` no cambian. `status` vuelve a `initial` en el
próximo `codeChanged`/`submit` — el status `authError` no se atora porque
`copyWith` limpia `authFailure` en cualquier otro status.)

## 10. `verify_email_form_fields.dart` (existente — actualización)

**Ruta:** `lib/features/auth/presentation/widgets/verify_email_form_fields.dart`

**Antes:**

```dart
        builder: (context, _) => BlocBuilder<VerifyEmailCubit, VerifyEmailState>(
          buildWhen: (p, c) =>
              p.code != c.code ||
              p.showCodeError != c.showCodeError ||
              p.isInProgress != c.isInProgress,
          builder: (context, state) {
            final code = state.code.value;
            final hasError = state.showCodeError && state.code.isNotValid;
```

**Después:**

```dart
        builder: (context, _) => BlocBuilder<VerifyEmailCubit, VerifyEmailState>(
          buildWhen: (p, c) =>
              p.code != c.code ||
              p.showCodeError != c.showCodeError ||
              p.isInProgress != c.isInProgress ||
              p.authFailure != c.authFailure,
          builder: (context, state) {
            final code = state.code.value;
            // Rojo en validación local O cuando el backend rechazó el
            // código (InvalidCodeFailure) — un código de 6 dígitos errado
            // es formz-válido, así que el flag local no basta.
            final hasError =
                (state.showCodeError && state.code.isNotValid) ||
                state.authFailure is InvalidCodeFailure;
```

(agregar `import '../../domain/failures/auth_failure.dart';`)

## 11. `verify_email_screen.dart` (existente — actualización)

**Ruta:** `lib/features/auth/presentation/screens/verify_email_screen.dart`

**Antes:**

```dart
                    BlocListener<VerifyEmailCubit, VerifyEmailState>(
                      listenWhen: (prev, curr) => prev.status != curr.status,
                      listener: (context, state) {
                        if (state.status == VerifyEmailStatus.success) {
                          TextInput.finishAutofillContext();
                          AppToast.success(
                            context,
                            l10n.verifyEmailDemoSuccess,
                          );
                        } else if (state.status == VerifyEmailStatus.failure) {
                          _codeFocus.requestFocus();
                          AppToast.error(context, l10n.verifyEmailFormInvalid);
                        }
                      },
                    ),
```

**Después:**

```dart
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
```

Y el helper junto a `_backToLogin` (reusa claves `loginError*` — mismos
textos; solo el código inválido tiene clave propia):

```dart
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
```

(importar `../../domain/failures/auth_failure.dart`.)

## 12. `setup_di.dart` (existente — actualización)

**Ruta:** `lib/core/di/setup_di.dart`

**Antes:**

```dart
  locator.registerFactoryParam<VerifyEmailCubit, String, void>(
    (email, _) => VerifyEmailCubit(email: email),
  );
```

**Después:**

```dart
  locator.registerLazySingleton<VerifyEmailUseCase>(
    () => VerifyEmailUseCase(locator<IAuthRepository>()),
  );
  locator.registerLazySingleton<ResendVerificationUseCase>(
    () => ResendVerificationUseCase(locator<IAuthRepository>()),
  );
  locator.registerFactoryParam<VerifyEmailCubit, String, void>(
    (email, _) => VerifyEmailCubit(
      email: email,
      verifyEmailUseCase: locator<VerifyEmailUseCase>(),
      resendVerificationUseCase: locator<ResendVerificationUseCase>(),
      authSession: locator<AuthSession>(),
    ),
  );
```

(+ imports de los dos use cases.)

## 13. `app_es.arb` (existente — actualización)

**Ruta:** `lib/l10n/app_es.arb`

- Agregar: `"verifyEmailErrorInvalidCode": "El código es incorrecto o ya expiró — pide uno nuevo."`
- Eliminar: `verifyEmailDemoSuccess` (ya no hay submit simulado).
- Ejecutar `flutter gen-l10n` (los `app_localizations*.dart` se regeneran, no se editan a mano).

## 14. Tests

- **`test/features/auth/presentation/cubit/verify_email_cubit_test.dart` (nuevo):**
  submit inválido local → failure + showCodeError; submit → éxito marca
  `AuthSession.isAuthenticated` + status success; `InvalidCodeFailure` →
  authError + authFailure; `TooManyAttemptsFailure` → authError; resend
  éxito → code limpio + tick + cooldown 60; resend fallo (429/red) →
  authError + **código conservado** + sin cooldown. (mocktail de ambos use
  cases + `AuthSession` real.)
- **`verify_email_screen_test.dart` (existente):** el `registerFactoryParam`
  del cubit ahora inyecta mocks de `VerifyEmailUseCase` +
  `ResendVerificationUseCase` + `AuthSession` real — sin eso falla la DI
  en cada pump.
- **`auth_repository_impl_test.dart` (existente):** extender con verify —
  200 persiste tokens + Right(user); 400 "Invalid or expired code" →
  `InvalidCodeFailure`; 429 → `TooManyAttemptsFailure`; offline →
  `NoConnectionFailure`; 200 malformado → `UnknownAuthFailure`. Resend —
  200 → `Right(null)`; 429 → tooMany; offline → noConnection.

---

## Orden de aplicación

1. `auth_failure.dart` (+ `InvalidCodeFailure`) → `i_auth_repository.dart` →
   use cases (2 archivos nuevos).
2. `i_auth_remote_datasource.dart` → `auth_remote_datasource_impl.dart` →
   `auth_repository_impl.dart` (+ mapping 400).
3. `verify_email_state.dart` → `verify_email_cubit.dart` →
   `verify_email_form_fields.dart` → `verify_email_screen.dart`.
4. `app_es.arb` → `flutter gen-l10n` → `setup_di.dart`.
5. Tests: cubit nuevo + screen/repository existentes → `flutter analyze` +
   `flutter test`.
6. Verificación manual contra backend real: `beto@depredadog.com` →
   `/verify-email` → código del log del backend → `/home`; código errado →
   casillas rojas + toast; resend → cooldown + código nuevo en el log.
