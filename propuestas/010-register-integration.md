# Propuesta 010: integración de `POST /auth/register` — FASE INTEGRACIÓN

Conecta la pantalla `/register` (aprobada, §008+§009) con el endpoint real.
El submit deja de ser simulado: crea la cuenta → el backend la deja
`pending_verification` y envía el código → la app navega a `/verify-email`
(flujo ya integrado en §006 — el auto-login ocurre ahí, no en register).

**Decisión del usuario (esta propuesta):**

| Punto | Resultado |
|---|---|
| 409 correo duplicado | **Volver al paso 2 marcando el campo Correo** — el error queda donde se corrige |

## Contrato del endpoint (verificado en `../pcalientes_backend`)

`POST /auth/register` — `@Public`, throttle **3 req/min**, 201:

| Campo | Req | Regla backend | Qué envía la app |
|---|---|---|---|
| `email` | sí | IsEmail | `email.value` (ya trimmeado) |
| `password` | sí | 8-72 | `password.value` |
| `firstName` | sí | 1-100, `Matches(/\S/)` | `firstName.value.trim()` |
| `firstLastName` | sí | 1-100, `Matches(/\S/)` | `firstLastName.value.trim()` |
| `secondName` | no | ≤100 | solo si no vacío (null → se omite) |
| `secondLastName` | no | ≤100 | solo si no vacío |
| `phone` | no | ≤20 | solo si no vacío (ya solo dígitos, máx 10) |
| `referralCode` | no | ≤20 | **no se envía** — sin campo en la UI (decisión §008) |
| `marketingOptIn` | no | bool | **no se envía** — sin checkbox (decisión §008) |
| `deviceFingerprint` | no | ≤255 | `IDeviceInfoProvider.fingerprint()` (mismo que login) |
| `platform` | no | `'android'\|'ios'` | `IDeviceInfoProvider.platform` |

**201 → `UserResponseDto`** (sin tokens): `id, email, firstName, secondName,
firstLastName, secondLastName, phone, role, status, emailVerifiedAt,
referralCode, marketingOptIn, createdAt`. `status` llega
`pending_verification`.

**Errores:** `409 "Email is already registered"` · `400 "Invalid referral
code"` · `400` validación de DTO · `429` throttle · 5xx/desconexión.

## Hallazgo a corregir: contrato de `User` desactualizado

La propuesta backend 004 (split LatAm) cambió `UserResponseDto`: ya no
existe `lastName` — ahora son `secondName/firstLastName/secondLastName`.
El `User`/`UserModel` de la app sigue leyendo `json['lastName']` → hoy
llega siempre `null` (bug silencioso, nada lo muestra todavía). Esta
integración **sincroniza la entidad al contrato real** — sin sync, login,
verify-email y `/auth/me` (que devuelven el mismo DTO) quedarían con
apellido vacío.

## Cambios por capa

### Dominio

- **`entities/user.dart`**: `lastName` → `firstLastName` (String, requerido
  en backend) + `secondName`/`secondLastName` (String?, opcionales). Nada
  más consume `lastName` en la app → cambio seguro.
- **`failures/auth_failure.dart`**: nuevo `EmailAlreadyRegisteredFailure`
  — 409 específico de register.
- **`repositories/i_auth_repository.dart`**: nuevo
  `Future<Either<AuthFailure, User>> register({required String email,
  required String password, required String firstName, String? secondName,
  required String firstLastName, String? secondLastName, String? phone})`.
  Doc: éxito = usuario creado `pending_verification`; NO persiste sesión
  (el endpoint no emite tokens — el auto-login ocurre en verify-email).
- **`use_cases/register_use_case.dart`** (nuevo): mirror de
  `LoginUseCase` — delega al repositorio, misma firma.

### Data

- **`i_auth_remote_datasource.dart`**: nuevo `Future<UserModel> register({...})`
  (misma firma que el repo + `deviceFingerprint`/`platform`). Devuelve el
  `UserResponseDto` crudo — no hay LoginResult porque no vienen tokens.
- **`auth_remote_datasource_impl.dart`**: `POST /auth/register` con body
  arriba; opcionales via null-aware entries (`?secondName`) — claves
  ausentes, no `null` explícito. `UserModel.fromJson(response)`.
- **`models/user_model.dart`**: parsea los 4 campos nuevos
  (`firstLastName` required; `secondName`/`secondLastName` nullable).
- **`auth_repository_impl.dart`**: `register()` — conectividad →
  fingerprint → remote.register → `Right(user)` (sin `saveSession`).
  `_mapFailure`: **`statusCode == 409` → `EmailAlreadyRegisteredFailure`**
  (en register el único 409 posible es email duplicado). `400 "Invalid
  referral code"` no se mapea — no enviamos referralCode; cae a Unknown
  (bug nuestro si llega, no caso UX).

### DI (`setup_di.dart`)

- `registerLazySingleton<RegisterUseCase>` (repo).
- `registerFactory<RegisterCubit>` — `RegisterCubit(registerUseCase: ...)`.
  NO recibe `AuthSession`: register no autentica (el auto-login es de
  verify-email).
- `register_screen.dart`: `create: (context) => locator<RegisterCubit>()`
  (reemplaza el `RegisterCubit()` local — patrón de login_screen).

### Estado (`register_state.dart`)

`authError`/`authFailure` ya quedaron listos (preparados en §009). Solo:

- Nuevo flag `emailTaken` (bool, default false) — distingue el error 409
  del error de formato en el mismo campo.
- `emailErrorKey()`: si `emailTaken` → `'taken'` (prioridad sobre el error
  de formato — el 409 es la razón real); si no, lo de hoy.
- `copyWith`: `emailTaken` en la firma + en props (Equatable).

### Cubit (`register_cubit.dart`)

- Constructor: `RegisterCubit({required RegisterUseCase registerUseCase})`
  — `simulatedDelay` sale (ya no hay simulación); los tests mockean el
  use case (mocktail, patrón existente).
- `emailChanged`: + `emailTaken: false` (editar el correo limpia el 409).
- `submit()`: tras validar → `inProgress` → `registerUseCase(...)`:
  - `Right(user)` → `status: success` (la pantalla navega igual que hoy:
    `/verify-email` con el email en `extra`).
  - `Left(EmailAlreadyRegisteredFailure)` → emite `authError` +
    `authFailure` **y en la misma emisión** `currentStep: 1`,
    `showEmailError: true`, `emailTaken: true` → luego `status: initial`
    (re-arma el listener). El salto de paso dispara el listener de
    `currentStep` (scroll reset) y el de `status` (toast + foco).
  - `Left(NoConnectionFailure/TooManyAttemptsFailure/UnknownAuthFailure)`
    → `authError` + `authFailure` → `initial`. Sin moverse de paso.

### Pantalla (`register_screen.dart`)

- Listener `authError` (rama nueva junto a `failure`): toast por tipo —
  `EmailAlreadyRegisteredFailure` → `registerEmailTaken` (nueva clave);
  `TooManyAttemptsFailure` → `loginErrorTooManyAttempts` (reusa);
  `NoConnectionFailure` → `loginErrorNoConnection` (reusa);
  resto → `loginErrorGeneric` (reusa) — mismo mapeo que login.
- `_focusFirstInvalid`: en paso 2 (índice 1), `email.isNotValid ||
  emailTaken` → `emailFocus` — el 409 enfoca el correo aunque su formato
  sea válido.
- Comentario `shouldSave:false`: confirmado como decisión — el modal de
  Google competiría con el OTP autofocus de verify-email (igual que
  login→verify). Se actualiza el comentario (ya no "se decide en
  integración").

### Widget (`register_step2_fields.dart`)

- `errorText` del email: `'taken' => l10n.registerEmailTaken` antes del
  fallback.

### l10n (`app_es.arb`)

- `registerEmailTaken`: "Este correo ya tiene cuenta" — mensaje genérico
  consistente con la convención de errores del wizard.

## Mapa de errores → UX

| Situación | Qué ve el usuario |
|---|---|
| 201 | Navega a `/verify-email` con su correo (código ya enviado) |
| 409 | Vuelve al paso 2: correo en rojo "Este correo ya tiene cuenta" + foco + toast igual |
| 429 | Toast "Demasiados intentos — espera un momento" (se queda en paso 3) |
| Sin conexión | Toast "Sin conexión a internet" |
| 400/5xx ajeno | Toast genérico `loginErrorGeneric` |

## Tests

- **`register_cubit_test`** (reescritura del setUp): `MockRegisterUseCase`
  (mocktail); casos nuevos: submit éxito → success (verifica args del use
  case, opcionales vacíos llegan null); 409 → authError + `currentStep:1`
  + `emailTaken:true` + secuencia authError→initial; 429/noConnection/
  unknown → authError sin cambiar de paso; `emailChanged` limpia
  `emailTaken`; `nextStep`/`prevStep` intactos.
- **`auth_repository_impl_test`**: register éxito → Right(user) y
  **`local.saveSession` NUNCA se llama** (verifyNever — no hay tokens);
  409 → EmailAlreadyRegisteredFailure; sin conexión → NoConnectionFailure
  sin tocar remote.
- **`register_use_case_test`** (nuevo): delega y propaga Either (patrón
  de los use-case tests existentes).
- **`register_screen_test`**: cubit mockeado — emisión authError 409
  pinta el paso 2 con "Este correo ya tiene cuenta" bajo Correo; éxito
  sigue navegando a `/verify-email`.
- **`user_model`**: casos de parseo se ajustan al contrato nuevo (los
  tests de repo/me que construyen el JSON de usuario actualizan
  `lastName` → los 4 campos).

## Fuera de alcance

- `referralCode`/`marketingOptIn` (sin UI — decisión §008).
- Auto-login desde register (el endpoint no emite tokens — ocurre en
  verify-email, ya integrado).
- Google sign-in en register (pendiente 006-google-oauth).
- `emailVerifiedAt`/`phone`/`referralCode`/`marketingOptIn`/`createdAt`
  en la entidad `User` (la doc de `user.dart` ya dice: se suman cuando
  una pantalla los necesite).

## Verificación

- `flutter analyze` limpio; `flutter test` suite completa.
- Manual en emulador con backend local: registro feliz → verify-email →
  código → home; repetir mismo correo → 409 en paso 2; avión → sin
  conexión; 4 submits seguidos → 429.
