# Propuesta 012: integración del flujo `/forgot-password` — FASE INTEGRACIÓN

Conecta el wizard `/forgot-password` (aprobado, §011) con los 3 endpoints
reales del backend. Los submits dejan de ser simulados: paso 1 envía el
código, paso 2 lo verifica sin consumirlo, paso 3 restablece la clave y
recibe tokens — el auto-login real reemplaza la sesión stub.

**Decisión del usuario (esta propuesta):**

| Punto | Resultado |
|---|---|
| Código inválido/expirado en el submit final (paso 3) | **Rebotar al paso 2 marcando el OTP** — el error queda donde se corrige (mismo patrón que el 409 de register §010) |
| Cooldown de reenvío al entrar al paso 2 | **Arranca en 60s tras el primer envío** — el código acaba de salir; un reenvío inmediato solo quema throttle |

## Contrato de los endpoints (verificado en `../pcalientes_backend`)

### `POST /auth/forgot-password` — throttle **3 req/min**

| Campo | Regla backend | Qué envía la app |
|---|---|---|
| `email` | IsEmail | `email.value` (ya trimmeado) |

**200 → `MessageResponseDto`** `{message}` — SIEMPRE 200, también si el
correo no existe o la cuenta está suspendida (anti-enumeración: no se
puede saber desde la app si el código realmente salió).

**Errores:** `400` validación de DTO (la UI ya impide email inválido —
bug nuestro si llega) · `429` throttle · 5xx/desconexión.

### `POST /auth/check-reset-code` — throttle **5 req/min**

| Campo | Regla backend | Qué envía la app |
|---|---|---|
| `email` | IsEmail | `email.value` |
| `code` | `Matches(/^\d{6}$/)` | `code.value` |

**200 → `MessageResponseDto`** `{message}` — el código existe, no está
consumido ni expirado. **El chequeo NO consume el código** (queda vivo
para el reset del paso 3 — diseño §005 backend).

**Errores:** `400 "Invalid or expired code"` (`InvalidAuthCodeException` —
código errado, expirado o ya consumido; genérico anti-enumeración, no los
distingue) · `429` · 5xx.

### `POST /auth/reset-password` — throttle **5 req/min**

| Campo | Regla backend | Qué envía la app |
|---|---|---|
| `email` | IsEmail | `email.value` |
| `code` | 6 dígitos | `code.value` |
| `newPassword` | 8-72 | `password.value` |
| `deviceFingerprint` | opcional ≤255 | `IDeviceInfoProvider.fingerprint()` |
| `platform` | `'android'\|'ios'` | `IDeviceInfoProvider.platform` |

**200 → `AuthResponseDto`** (mismo shape que login/verify-email):
`user` + `accessToken` + `refreshToken` — **auto-login real**: el repo
persiste la sesión como en verifyEmail.

**Errores:** `400 "Invalid or expired code"` — la carrera real: el
código pudo expirar o ser consumido ENTRE el check del paso 2 y este
submit (el check no lo consume); `400` validación DTO · `429` · 5xx.

## Cambios por capa

### Dominio

- **`repositories/i_auth_repository.dart`** — 3 métodos nuevos:
  - `Future<Either<AuthFailure, void>> forgotPassword({required String
    email})` — doc: éxito = el backend aceptó el pedido (200 genérico
    anti-enumeración, no garantiza que el correo exista). Sin sesión.
  - `Future<Either<AuthFailure, void>> checkResetCode({required String
    email, required String code})` — doc: éxito = código vivo y NO
    consumido (sigue disponible para resetPassword).
  - `Future<Either<AuthFailure, User>> resetPassword({required String
    email, required String code, required String newPassword})` — doc:
    éxito = contraseña cambiada + sesión YA persistida (el endpoint
    emite IssuedSession igual que verifyEmail — auto-login).
- **NO hacen falta failures nuevos**: `InvalidCodeFailure` ya cubre
  `400 "Invalid or expired code"` (mismo mapeo que verify-email);
  `TooManyAttemptsFailure`/`NoConnectionFailure`/`UnknownAuthFailure`
  también existen.
- **`use_cases/`** — 3 archivos nuevos, mirror de `VerifyEmailUseCase`/
  `ResendVerificationUseCase` (delegan al repositorio, misma firma):
  - `forgot_password_use_case.dart`
  - `check_reset_code_use_case.dart`
  - `reset_password_use_case.dart`

### Data

- **`i_auth_remote_datasource.dart`**:
  - `Future<void> forgotPassword({required String email})`
  - `Future<void> checkResetCode({required String email, required
    String code})`
  - `Future<LoginResult> resetPassword({required String email, required
    String code, required String newPassword, String?
    deviceFingerprint, String? platform})` — emite sesión → reutiliza
    `LoginResult` (como login/verifyEmail).
- **`auth_remote_datasource_impl.dart`**: los 3 POST con los bodies del
  contrato; `resetPassword` parsea `LoginResult` (accessToken/
  refreshToken/UserModel.fromJson).
- **`auth_repository_impl.dart`**:
  - `forgotPassword()` / `checkResetCode()` — conectividad → remote →
    `Right(null)` (sin fingerprint: los endpoints no lo reciben).
  - `resetPassword()` — conectividad → fingerprint → remote →
    `localDataSource.saveSession(accessToken, refreshToken)` →
    `Right(result.user)` (idéntico a `verifyEmail`).
  - `_mapFailure`: **sin cambios** — `400 "Invalid or expired code"`
    ya → `InvalidCodeFailure`, `429` ya → `TooManyAttemptsFailure`.

### DI (`setup_di.dart`)

- `registerLazySingleton` para los 3 use cases nuevos.
- `registerFactory<ForgotPasswordCubit>` — ahora recibe los use cases
  además de `AuthSession`:
  `ForgotPasswordCubit(forgotPasswordUseCase:, checkResetCodeUseCase:,
  resetPasswordUseCase:, authSession:)`.

### Estado (`forgot_password_state.dart`)

- Enum: nuevo `authError` (queda `{initial, inProgress, success,
  failure, authError}`) — mismo patrón que `VerifyEmailStatus`.
- Nuevo `final AuthFailure? authFailure` — solo tiene valor cuando
  `status == authError`; `copyWith` lo nullea en cualquier otro status
  (mismo truco que verify-email, línea 62-64 de su state).
- Firma de `copyWith` + `props` actualizadas.

### Cubit (`forgot_password_cubit.dart`)

- Constructor: `ForgotPasswordCubit({required ForgotPasswordUseCase
  forgotPasswordUseCase, required CheckResetCodeUseCase
  checkResetCodeUseCase, required ResetPasswordUseCase
  resetPasswordUseCase, required this._authSession})`. **`simulatedDelay`
  sale** — ya no hay simulación; los tests mockean los use cases
  (mocktail, patrón §010).
- `nextStep()` pasa a `Future<void>`:
  - **Paso 0** (`isStep1Valid`): `inProgress` → `forgotPassword(email)`
    → `Right` → `currentStep: 1` **+ `code: CodeInput.pure()` +
    `showCodeError: false` + `resendCooldown: 60` + `_startCooldown()`**
    (limpiar el OTP cubre el caso "cambié el correo y volví a pedir
    código": el viejo quedó invalidado por el nuevo envío; el cooldown
    arranca porque un reenvío inmediato no tiene sentido — decisión de
    esta propuesta). `Left` → `authError` + `authFailure` → `initial`.
  - **Paso 1** (`isStep2Valid`): `inProgress` → `checkResetCode(email,
    code)` → `Right` → `currentStep: 2`. `Left` → `authError` +
    `authFailure` → `initial` (InvalidCodeFailure pinta las casillas en
    rojo vía `hasError` del widget; el toast va por listener).
  - Paso 2: sin cambios (la acción es `submit`).
- `resend()`: el reenvío ES `forgotPassword(email)` otra vez (el
  endpoint no tiene variante de reenvío — mismo envío). Éxito → limpia
  código + error + cooldown 60 + `resendTick++` (hoy lo hace tras el
  delay simulado; ahora tras el `Right`). Fallo → `isResending: false`
  + `authError` + `authFailure` y **el código tipeado se conserva**
  (sigue vivo en el server — convención verify).
- `submit()`: `inProgress` → `resetPassword(email, code,
  password)` →
  - `Right(user)` → `_authSession.markAuthenticated(user)` con el
    usuario REAL (reemplaza el stub `forgot-preview` — los tokens ya
    quedaron persistidos por el repo) → `success` → /home.
  - `Left(InvalidCodeFailure)` → **rebota al paso 2**: `currentStep: 1`
    + `status: authError` + `authFailure` + `code` se conserva (el
    usuario ve sus dígitos en rojo y puede corregir o reenviar — el
    cooldown puede seguir corriendo). → `initial`.
  - `Left(otros)` → `authError` + `authFailure` → `initial` (se queda
    en paso 3).

### Pantalla (`forgot_password_screen.dart`)

- Listener `status`: nueva rama `authError` → toast por tipo de
  `authFailure` (método `_authErrorMessage` espejo de verify-email):
  `InvalidCodeFailure` → `l10n.verifyEmailErrorInvalidCode` (reusa —
  el texto "El código es incorrecto o ya expiró — pide uno nuevo" ya
  describe el caso); `TooManyAttemptsFailure` →
  `l10n.loginErrorTooManyAttempts`; `NoConnectionFailure` →
  `l10n.loginErrorNoConnection`; resto → **nueva clave**
  `forgotErrorGeneric`.
- Comentario de `BlocProvider`/`create`: quitar la nota "los use cases
  llegan con la integración".
- Comentario del `submit` simulado y de la sesión stub: actualizar —
  ahora es flujo real.

### Widget (`forgot_step2_code.dart`)

- `hasError` del OTP: `(state.showCodeError && state.code.isNotValid)
  || state.authFailure is InvalidCodeFailure` — las casillas se pintan
  en rojo cuando el SERVER rechazó el código (convención verify-email).
- `buildWhen` del builder del OTP: + `p.authFailure != c.authFailure`.

### l10n (`app_es.arb`)

- `forgotErrorGeneric`: **"No se pudo restablecer la contraseña,
  intenta de nuevo"** — la clave genérica (`loginErrorGeneric` dice
  "iniciar sesión", contexto equivocado; mismo razonamiento que llevó a
  `registerErrorGeneric` en §010).

## Mapa de errores → UX

| Situación | Qué ve el usuario |
|---|---|
| Paso 1: 200 | Avanza al paso 2, OTP vacío, cooldown 60s corriendo |
| Paso 1: 429 / sin red / 5xx | Toast según tipo — se queda en paso 1, correo intacto |
| Paso 2: código válido | Avanza al paso 3 |
| Paso 2: código malo/expirado | Casillas rojas + toast "El código es incorrecto o ya expiró — pide uno nuevo" |
| Paso 2: 429 / sin red | Toast — dígitos conservados |
| Paso 3: 200 | Auto-login real → `/home` con sesión persistida |
| Paso 3: código expiró entre check y submit | Rebota al paso 2, dígitos en rojo + toast de código inválido |
| Paso 3: 429 / sin red | Toast — se queda en paso 3, claves intactas |
| Reenviar: 200 | "Código reenviado" + OTP limpio + cooldown 60s |
| Reenviar: fallo | Toast — dígitos conservados (el viejo sigue vivo) |

## Tests

- **`forgot_password_cubit_test`** (reescritura del setUp): mocks de los
  3 use cases (mocktail). Casos: nextStep paso 0 éxito → paso 1 + OTP
  limpio + cooldown corriendo; paso 0 fallo → authError sin mover paso;
  nextStep paso 1 éxito → paso 2; paso 1 InvalidCode → authError +
  authFailure; resend éxito limpia código; resend fallo conserva
  dígitos; submit éxito → markAuthenticated con usuario real + success;
  submit InvalidCode → currentStep:1 + authError; submit 429 →
  authError en paso 3.
- **`auth_repository_impl_test`**: forgotPassword/checkResetCode éxito →
  `Right(null)` y `saveSession` NUNCA se llama (verifyNever);
  resetPassword éxito → `saveSession` llamado con ambos tokens +
  `Right(user)`; 400 "Invalid or expired code" → `InvalidCodeFailure`
  en checkResetCode y en resetPassword; sin conexión →
  `NoConnectionFailure` sin tocar remote.
- **Use-case tests** (3 nuevos): delegan y propagan Either (patrón de
  los tests existentes).
- **`forgot_password_screen_test`**: cubit mockeado — emisión authError
  con InvalidCodeFailure en paso 2 pinta las casillas con error +
  toast; rebote al paso 2 desde submit; éxito navega a `/home`.

## Fuera de alcance

- Pantalla de "correo enviado" separada (el 200 genérico anti-
  enumeración no permite confirmar que el correo existe — el paso 2
  con el subtítulo "Enviamos un código a {email}" ya es la respuesta
  honesta).
- Reenvío con endpoint dedicado (no existe — resend = forgotPassword).
- Google sign-in (pendiente propio).

## Verificación

- `flutter analyze` limpio; `flutter test` suite completa.
- Manual en emulador con backend local: flujo feliz correo → código
  (del log del backend) → nueva clave → `/home` con sesión real
  (reiniciar app → sigue logueado vía `/auth/me`); código errado →
  casillas rojas; código correcto en paso 2 pero esperar expiración →
  submit rebota al paso 2; avión → sin conexión; spam → 429.
