# Propuesta 014: integración `POST /auth/google` — Google Sign-In real

Fase 2 de integración para el `GoogleSignInButton` (ya presente en login y
register paso 1, §013): hoy muestra el toast provisional "Disponible
próximamente". Con esta propuesta el botón lanza el flujo nativo de Google,
envía el `idToken` al backend y completa el auto-login con tokens reales.

**Contrato backend (verificado):** `POST /auth/google` público, throttle
5/min. Body: `{ idToken (10-4096), deviceFingerprint?, platform?: 'android'|'ios' }`.
Respuesta 200 = `AuthResponseDto` (user + access/refresh — misma forma que
login). El use case del server: si el correo ya existe enlaza `googleId`,
si estaba `pending_verification` lo activa directo (Google ya probó el
correo), si no existe crea la cuenta `ACTIVE` con referral. Errores:
401 `Invalid Google token`, 403 `Account is suspended`, 409 linked
(inalcanzable desde este endpoint hoy).

**Decisiones del usuario (encuesta aplicada):**

| Decisión | Resultado |
|---|---|
| Cancel del picker | **Silencioso** — vuelve al estado inicial sin toast |
| Error de Google/backend | Un solo toast genérico "No pudimos entrar con Google — inténtalo de nuevo" + reutiliza suspended/noConnection/tooManyAttempts |
| Client ID vacío | **Sin gate — el botón siempre lanza el flujo** (decisión del usuario: "que falle para ver cómo se comporta"): sin `GOOGLE_SERVER_CLIENT_ID` el `initialize`/`authenticate` del SDK falla → toast genérico. Comportamiento real desde el primer build |
| Éxito en register | **/home directo** — la sesión Google nace completa (sin verify-email); se distingue con flag `isGoogleAuth` en el state |

---

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `pubspec.yaml` | `flutter pub add google_sign_in` (^7.2.0) |
| `lib/core/constants/environment/environment.dart` | +`googleServerClientId` |
| `lib/features/auth/data/datasources/interfaces/i_google_sign_in_gateway.dart` | **nuevo** — puerto del SDK Google |
| `lib/features/auth/data/datasources/implementations/google_sign_in_gateway_impl.dart` | **nuevo** — wrapper de `google_sign_in` |
| `lib/features/auth/data/datasources/interfaces/i_auth_remote_datasource.dart` | +`googleLogin()` |
| `lib/features/auth/data/datasources/implementations/auth_remote_datasource_impl.dart` | impl `googleLogin` → POST /auth/google |
| `lib/features/auth/domain/repositories/i_auth_repository.dart` | +`signInWithGoogle()` |
| `lib/features/auth/data/repositories/auth_repository_impl.dart` | impl `signInWithGoogle` (gateway→remote→saveSession) |
| `lib/features/auth/domain/use_cases/google_sign_in_use_case.dart` | **nuevo** |
| `lib/core/di/setup_di.dart` | registrar gateway + use case |
| `lib/features/auth/presentation/widgets/google_sign_in_button.dart` | +`onPressed` (nulo = toast provisional) |
| `lib/features/auth/presentation/cubit/login_cubit.dart` | +`signInWithGoogle()` + ctor param |
| `lib/features/auth/presentation/cubit/register_cubit.dart` | +`signInWithGoogle()` + ctor param |
| `lib/features/auth/presentation/cubit/register_state.dart` | +flag `isGoogleAuth` |
| `lib/features/auth/presentation/screens/login_screen.dart` | wire `onPressed` + gate env |
| `lib/features/auth/presentation/screens/register_screen.dart` | wire `onPressed` + gate env + success→/home si google |
| `lib/l10n/app_es.arb` | +`googleSignInError` → `flutter gen-l10n` |
| tests | use case, repository impl, ambos cubits, wiring en screens |

---

## 1. `i_google_sign_in_gateway.dart` (nuevo)

**Ruta:** `lib/features/auth/data/datasources/interfaces/i_google_sign_in_gateway.dart`

```dart
/// Puerto del SDK de Google Sign-In (no es un datasource HTTP — envuelve el
/// plugin `google_sign_in`). La implementación es la única que conoce el
/// paquete; el repository depende de esta interfaz como de las demás.
abstract class IGoogleSignInGateway {
  /// Lanza el flujo nativo y devuelve el idToken listo para el backend.
  /// `null` = el usuario canceló el selector de cuentas (caso silencioso —
  /// la UI no muestra nada). Errores del SDK (sin Play Services, init
  /// fallida, red del propio flujo) propagan como excepción — el repository
  /// los traduce a failure genérico.
  Future<String?> getIdToken();
}
```

## 2. `google_sign_in_gateway_impl.dart` (nuevo)

**Ruta:** `lib/features/auth/data/datasources/implementations/google_sign_in_gateway_impl.dart`

```dart
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../../core/constants/environment/environment.dart';
import '../interfaces/i_google_sign_in_gateway.dart';

/// Wrapper del plugin `google_sign_in` v7: initialize() una sola vez (lazy,
/// al primer tap — sin costo de arranque) con el serverClientId del
/// --dart-define; authenticate() abre el selector nativo y devuelve el
/// idToken. Cancel = GoogleSignInException(code: canceled) → null.
class GoogleSignInGatewayImpl implements IGoogleSignInGateway {
  GoogleSignInGatewayImpl({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;
  bool _initialized = false;

  @override
  Future<String?> getIdToken() async {
    if (!_initialized) {
      await _signIn.initialize(
        serverClientId: Environment.googleServerClientId,
      );
      _initialized = true;
    }
    try {
      final account = await _signIn.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }
}
```

## 3. `i_auth_remote_datasource.dart` — agregar método

**Antes** (al final de la interfaz, tras `resetPassword`):

```dart
  /// Restablece la contraseña ... LoginResult.
  Future<LoginResult> resetPassword({...});
}
```

**Después:**

```dart
  /// Restablece la contraseña ... LoginResult.
  Future<LoginResult> resetPassword({...});

  /// /auth/google — mismo LoginResult que login/verify/reset (el endpoint
  /// emite IssuedSession). El idToken sale del SDK de Google (gateway);
  /// el repository lo pasa junto a fingerprint/platform como en login.
  Future<LoginResult> googleLogin({
    required String idToken,
    String? deviceFingerprint,
    String? platform,
  });
}
```

## 4. `auth_remote_datasource_impl.dart` — agregar método

```dart
  @override
  Future<LoginResult> googleLogin({
    required String idToken,
    String? deviceFingerprint,
    String? platform,
  }) {
    return _postLoginResult('/auth/google', {
      'idToken': idToken,
      'deviceFingerprint': ?deviceFingerprint,
      'platform': ?platform,
    });
  }
```

(si el impl no tiene helper `_postLoginResult`, replicar el cuerpo de
`login`: `_networkService.post('/auth/google', data: {...})` →
`LoginResult.fromJson` — seguir el patrón exacto del archivo.)

## 5. `i_auth_repository.dart` — agregar método

```dart
  /// Google sign-in completo (SDK nativo → POST /auth/google). Éxito =
  /// sesión YA persistida (el endpoint emite tokens igual que login).
  /// Right(null) = el usuario canceló el selector de Google — no es error,
  /// la UI no muestra nada.
  Future<Either<AuthFailure, User?>> signInWithGoogle();
```

## 6. `auth_repository_impl.dart` — agregar método

Nueva dependencia `IGoogleSignInGateway` por constructor (registrada en
setup_di como los demás datasources).

```dart
  @override
  Future<Either<AuthFailure, User?>> signInWithGoogle() async {
    if (!await _networkInfo.isConnected) {
      return const Left(NoConnectionFailure());
    }
    try {
      final idToken = await _googleGateway.getIdToken();
      if (idToken == null) return const Right(null); // cancel silencioso
      final fingerprint = await _deviceInfoProvider.fingerprint();
      final result = await _remoteDataSource.googleLogin(
        idToken: idToken,
        deviceFingerprint: fingerprint,
        platform: _deviceInfoProvider.platform,
      );
      await _localDataSource.saveSession(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      return Right(result.user);
    } on NetworkException catch (e) {
      // _mapFailure ya cubre el contrato: 401 'Invalid Google token' →
      // InvalidCredentials (el cubit lo traduce al toast de Google),
      // 403 suspended, 429, 5xx → Unknown.
      return Left(_mapFailure(e));
    } catch (e) {
      // Incluye errores del SDK de Google (gateway) — misma red de
      // seguridad que login: nada escapa al cubit.
      return Left(UnknownAuthFailure(e.toString()));
    }
  }
```

Sin failures nuevos: el sealed `AuthFailure` queda intacto.

## 7. `google_sign_in_use_case.dart` (nuevo)

**Ruta:** `lib/features/auth/domain/use_cases/google_sign_in_use_case.dart`

```dart
import 'package:dartz/dartz.dart';

import '../entities/user.dart';
import '../failures/auth_failure.dart';
import '../repositories/i_auth_repository.dart';

/// Google sign-in end-to-end (SDK → backend → sesión persistida).
/// Right(null) = cancel del usuario en el picker de Google.
class GoogleSignInUseCase {
  const GoogleSignInUseCase(this._repository);

  final IAuthRepository _repository;

  Future<Either<AuthFailure, User?>> call() => _repository.signInWithGoogle();
}
```

## 8. `environment.dart` — agregar constante

```dart
  /// Client ID **web** de Google Cloud — el SDK lo usa para emitir el
  /// idToken que el backend verifica contra GOOGLE_CLIENT_IDS. Vacío =
  /// Google sign-in no configurado (pendiente 006) — la UI muestra el
  /// toast provisional en vez de lanzar el flujo.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );
```

## 9. `google_sign_in_button.dart` — +`onPressed`

**Antes:**

```dart
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key});
  ...
        onPressed: () => AppToast.success(context, l10n.comingSoon),
```

**Después:**

```dart
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, this.onPressed});

  /// null = sin integración configurada todavía — el botón queda en su
  /// comportamiento provisional (toast "Disponible próximamente").
  final VoidCallback? onPressed;

  ...
        onPressed: onPressed ?? () => AppToast.success(context, l10n.comingSoon),
```

## 10. `login_cubit.dart` — +`signInWithGoogle()`

Ctor: `LoginCubit({required LoginUseCase loginUseCase, required GoogleSignInUseCase googleSignInUseCase, required AuthSession authSession})`.

```dart
  /// Flujo Google: cancel = vuelve a initial en silencio; éxito = sesión
  /// persistida → markAuthenticated → success → el listener navega a /home.
  Future<void> signInWithGoogle() async {
    if (state.isInProgress) return;
    emit(state.copyWith(status: LoginStatus.inProgress));
    final result = await _googleSignInUseCase();
    if (isClosed) return;
    result.fold(
      (failure) {
        emit(
          state.copyWith(status: LoginStatus.authError, authFailure: failure),
        );
        emit(state.copyWith(status: LoginStatus.initial));
      },
      (user) {
        if (user == null) {
          emit(state.copyWith(status: LoginStatus.initial));
          return;
        }
        _authSession.markAuthenticated(user);
        emit(state.copyWith(status: LoginStatus.success));
      },
    );
  }
```

## 11. `register_cubit.dart` — +`signInWithGoogle()`

Misma forma, con `RegisterStatus` y además `isGoogleAuth: true` en el éxito.

## 12. `register_state.dart` — +flag `isGoogleAuth`

Campo `final bool isGoogleAuth;` (default false), en copyWith: se resetea a
false en cualquier copyWith que no lo reciba explícito con success —
siguiendo la convención de `authFailure` (se limpia entre intentos):
`isGoogleAuth: status == RegisterStatus.success ? (isGoogleAuth ?? this.isGoogleAuth) : false`.
El listener de la pantalla: `success && isGoogleAuth → context.go('/home')`,
`success && !isGoogleAuth → /verify-email` (comportamiento actual intacto).

## 13. `login_screen.dart` — wire

```dart
  // Sin gate de Environment (decisión del usuario): si el client ID está
  // vacío el SDK falla y el usuario ve el toast genérico — comportamiento
  // real desde el primer build.
  GoogleSignInButton(
    onPressed: () => context.read<LoginCubit>().signInWithGoogle(),
  ),
```

## 14. `register_screen.dart` — wire + listener

Igual que login (onPressed directo al cubit). En el BlocListener de
success: `state.isGoogleAuth ? context.go(AuthGuard.homeRoute) : context.go(AuthGuard.verifyEmailRoute, extra: ...)`.

## 15. `setup_di.dart`

`locator.registerLazySingleton<IGoogleSignInGateway>(() => GoogleSignInGatewayImpl());`
`locator.registerFactory(() => GoogleSignInUseCase(locator()));`
Actualizar las factories de `LoginCubit`/`RegisterCubit` con el nuevo param.

## 16. `app_es.arb` — nueva clave

`"googleSignInError": "No pudimos entrar con Google — inténtalo de nuevo",`
→ `flutter gen-l10n`. Mapeo en `_authErrorMessage` de ambas pantallas:
`NoConnectionFailure → loginErrorNoConnection`, `TooManyAttemptsFailure →
loginErrorTooManyAttempts`, `AccountSuspendedFailure → loginErrorAccountSuspended`,
resto → `googleSignInError`.

## 17. Tests

- `google_sign_in_use_case_test.dart`: éxito → Right(user); cancel → Right(null); failure → Left.
- `auth_repository_impl_test.dart`: gateway null → Right(null) sin llamada remota; ok → remote llamado con fingerprint/platform + saveSession; NetworkException → failure mapeada.
- `login_cubit_test.dart` / `register_cubit_test.dart`: éxito → markAuthenticated + success; cancel → initial sin authFailure; failure → authError + toast path; guard isInProgress.
- `register_screen_test.dart`: éxito google → /home (router test); `isGoogleAuth` no rompe el éxito email → /verify-email.
- Screen wiring: tap en el botón invoca `signInWithGoogle` del cubit (sin gate — siempre cableado).

## 18. Docs

- `pendientes/006-google-oauth.md`: `GOOGLE_SERVER_CLIENT_ID` ya declarado en
  environment.dart — queda el pendiente solo del valor real + SHA-1s.
- `design-system.yaml`: spec de `google_sign_in_button` pasa de PROVISIONAL a
  integrado (copy, onPressed, gate env) — tras aprobación visual.

---

## Orden de aplicación

1. `flutter pub add google_sign_in`
2. environment + datasource interfaces + impls
3. repository interface + impl
4. use case + gateway impl + setup_di
5. botón + cubits + state + screens + arb + gen-l10n
6. tests
7. analyze + test + APK en emulador
