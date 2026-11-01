# Propuesta 011: `/forgot-password` wizard de 3 pasos — FASE PRESENTACIÓN

Pantalla de recuperación de contraseña. **Fase presentación** — los
submit son simulados; la integración real llega después (el backend ya
tiene los 3 endpoints: `forgot-password`, `check-reset-code` — nuevo en
`b49c472` — y `reset-password`).

**Decisión del usuario:** 3 pasos — "se envía el código, se verifica y
se ingresa la contraseña" (mismo modelo wizard que `/register` 009).

## Decisiones

| Decisión | Resultado |
|---|---|
| Paso 1 | Correo → "Enviar código" (simulado → paso 2) |
| Paso 2 | OTP 6 dígitos + "Reenviar" con cooldown → "Verificar" (simulado → paso 3) |
| Paso 3 | Nueva contraseña + confirmar → "Cambiar contraseña" (simulado → `/home`, espejo del auto-login real) |
| Stepper | Mismo componente de register — **extraído a widget genérico** `WizardStepper` (labels + currentStep por parámetro) |
| OTP | Mismo diseño de 6 casillas de verify-email — **extraído a widget genérico** `SixDigitCodeField` |
| Flecha superior | **Siempre sale a /login** (abandonar recuperación), cualquier paso |
| "Atrás" secundario | Paso previo (pasos 2-3), junto al botón primario |
| Back nativo | Paso previo; en paso 1 sale |
| Teclado | Nunca abre solo al cambiar de paso — solo al tocar campo o al fallar validación (foco al primer inválido) |
| Errores | Genéricos: "Correo incorrecto" / "Contraseña incorrecta" / "Las contraseñas no coinciden" / código "Ingresa los 6 dígitos" |
| Entrada | `/forgot-password` desde el link del login (el toast "coming soon" provisional se reemplaza por navegación) |

## Estructura por paso

```
PASO 1 "¿Olvidaste tu llave?"      PASO 2 "Revisa tu correo"         PASO 3 "Crea tu nueva llave"
┌─────────────────────────┐        ┌─────────────────────────┐       ┌─────────────────────────┐
│ ←  (●)───(○)───(○)      │        │ ←  (✓)───(●)───(○)      │       │ ←  (✓)───(✓)───(●)      │
│    Correo  Código  Clave│        │    Correo  Código  Clave│       │    Correo  Código  Clave│
│                         │        │                         │       │                         │
│ ¿Olvidaste tu llave?    │        │ Revisa tu correo        │       │ Crea tu nueva llave     │
│ Te enviamos un código   │        │ Enviamos un código de   │       │ Elige una que no uses   │
│ para restablecerla.     │        │ 6 dígitos a {email}.    │       │ en otro lado.           │
│                         │        │                         │       │                         │
│ Correo electrónico *    │        │ [6 casillas OTP]        │       │ Nueva contraseña * (ojo)│
│                         │        │ ¿No llegó? Reenviar     │       │   "Mínimo 8 caracteres" │
│                         │        │   (cooldown 60s)        │       │ Confirmar contraseña *  │
│                         │        │                         │       │        (ojo)            │
│ [ Enviar código ]       │        │ Atrás  [ Verificar ]    │       │ Atrás [Cambiar contraseña]
│ ¿Ya tienes cuenta? ...  │        │ ¿Ya tienes cuenta? ...  │       │ ¿Ya tienes cuenta? ...  │
└─────────────────────────┘        └─────────────────────────┘       └─────────────────────────┘
```

- **Stepper**: mismo visual de register (círculo lleno/completado ✓/
  pendiente outline + conectores + labels). Labels: **Correo / Código /
  Clave**.
- **Resend con cooldown**: patrón verify-email — "Reenviar" activo →
  tap → cooldown 60s con cuenta regresiva (simulado en presentación).
- **OTP**: 6 casillas, casilla activa con borde primario, error → todas
  en rojo (mismo lenguaje que verify-email).
- **Transición**: `AnimatedSwitcher` ~250ms + `AnimatedSize` (igual que
  register), contenido top-aligned, stepper fijo fuera del scroll,
  scroll reset al cambiar de paso.
- **Éxito simulado**: paso 3 → delay ~800ms → `/home` (el flujo real
  hace auto-login con los tokens del reset — mismo destino).

## Reutilización / extracciones (presentación)

| Pieza | De dónde | Cómo |
|---|---|---|
| `WizardStepper` | extraído de `RegisterStepper` | params `labels: List<String>`, `currentStep: int`, `progressLabel: String`; `RegisterStepper` queda como wrapper fino que lee su cubit y pasa labels (o se reemplaza por uso directo — lo que salga más limpio). Tests de register cubren la regresión visual. |
| `SixDigitCodeField` | extraído de `VerifyEmailFormFields` (el hidden TextField + 6 `_PinCell`) | params `controller`, `focusNode`, `hasError`, `onChanged`, `onSubmitted`; verify-email lo rebinda a su cubit, el wizard lo usa con el suyo. Suite de verify (ya integrada) cubre la regresión. |
| Inputs Formz | `login_inputs.dart`/`register_inputs.dart` | `EmailInput`, `RegisterPasswordInput`, `ConfirmPasswordInput` reutilizados sin tocar; nuevo `CodeInput` (6 dígitos — ¿ya existe en verify? si existe se mueve a compartido, si no se crea en `forgot_inputs.dart`). |
| Field wrapper | `register_field.dart` | se usa tal cual si es paramétrico (label+child+error); si está acoplado a register se generaliza a `form_field.dart`. |
| Footer login | `register_login_footer.dart` | "¿Ya tienes cuenta? Inicia sesión" — misma frase: se reutiliza (si su l10n es genérica) o se parametrizea el link. |
| Navegación | `auth_guard.dart` | `/forgot-password` ya es pública — solo falta registrar la `GoRoute` y el link del login. `/reset-password` queda reservada (sin uso — el wizard cubre los 3 pasos). |

## Archivos

| Archivo | Acción |
|---|---|
| `lib/features/auth/presentation/widgets/wizard_stepper.dart` | nuevo — stepper genérico extraído |
| `lib/features/auth/presentation/widgets/six_digit_code_field.dart` | nuevo — OTP genérico extraído |
| `lib/features/auth/presentation/widgets/register_stepper.dart` | refactor — usa el genérico |
| `lib/features/auth/presentation/widgets/verify_email_form_fields.dart` | refactor — usa el OTP genérico |
| `lib/features/auth/presentation/cubit/forgot_password_cubit.dart` | nuevo — cubit del wizard (submit simulado, `simulatedDelay` inyectable como register) |
| `lib/features/auth/presentation/cubit/forgot_password_state.dart` | nuevo — state (paso actual, inputs, flags, resendCooldown, status) |
| `lib/features/auth/presentation/inputs/forgot_inputs.dart` | nuevo — `CodeInput` si no existe compartido |
| `lib/features/auth/presentation/screens/forgot_password_screen.dart` | nuevo — shell del wizard |
| `lib/features/auth/presentation/widgets/forgot_step1_email.dart` | nuevo — paso 1 |
| `lib/features/auth/presentation/widgets/forgot_step2_code.dart` | nuevo — paso 2 (OTP + reenviar) |
| `lib/features/auth/presentation/widgets/forgot_step3_password.dart` | nuevo — paso 3 |
| `lib/core/routes/app_router.dart` | + `GoRoute /forgot-password` |
| `lib/features/auth/presentation/widgets/login_form_fields.dart` | link "¿Olvidaste tu contraseña?" → navega (reemplaza toast provisional) |
| `lib/l10n/app_es.arb` + generados | claves nuevas del wizard |
| `test/features/auth/presentation/cubit/forgot_password_cubit_test.dart` | nuevo |
| `test/features/auth/presentation/screens/forgot_password_screen_test.dart` | nuevo |
| `Design/design-system.yaml` | bump minor + spec del wizard |

## l10n (nuevas claves — español)

`forgotTitle` "¿Olvidaste tu llave?" · `forgotSubtitle` "Te enviamos un
código para restablecerla." · `forgotSendCode` "Enviar código" ·
`forgotStepEmailLabel/CodeLabel/PasswordLabel` "Correo"/"Código"/"Clave"
· `forgotCodeTitle` "Revisa tu correo" · `forgotCodeSubtitle{email}` —
misma frase de verify ("Enviamos un código de 6 dígitos a {email}." —
reutilizar la clave existente si es compartible) · `forgotResend`
"Reenviar" + `forgotResendCooldown{seconds}` · `forgotCodeRequired`
"Ingresa los 6 dígitos" · `forgotPasswordTitle` "Crea tu nueva llave" ·
`forgotPasswordSubtitle` "Elige una que no uses en otro lado." ·
`forgotNewPasswordLabel` "Nueva contraseña" · `forgotConfirmLabel`
"Confirmar contraseña" · `forgotSubmit` "Cambiar contraseña" ·
`forgotStepProgress{step,total}` "Paso {step} de {total}" (reutilizar
la de register si existe)

## State / Cubit (espejo de `RegisterCubit`)

- `currentStep` 0-2; `nextStep()` valida SOLO los inputs del paso;
  `submit()` (paso 3) revalida todo → simulated delay → success.
- `resend()` → cooldown 60s simulado.
- Flags de error por campo (`showEmailError`, `codeError`,
  `showPasswordError`, `showConfirmPasswordError`), `emailErrorKey()`
  etc. — mismo patrón que register/verify.
- `isInProgress` guard en `*Changed`/`nextStep`/`submit` (el guard del
  submit real ya aplicado en register).
- Status: `initial / inProgress / success / failure` (sin `authError` —
  la integración lo agrega cuando conecte los endpoints).

## Tests

- **Cubit**: por-paso validación, avance/retroceso, flags de error,
  resend cooldown, guard de edición durante submit, submit simulado
  success.
- **Screen**: render por paso, stepper refleja progreso, navegación
  (flecha→/login, "Atrás"→paso previo, back nativo), email viaja al
  subtítulo del paso 2, éxito → ruta destino.
- **Inputs**: `CodeInput` 6 dígitos.
- **Regresión**: suite completa debe quedar verde (register+verify sin
  romperse por las extracciones) + revisión visual de `/register` y
  `/verify-email` en emulador tras el refactor.

## Fuera de alcance (integración posterior)

- Llamadas reales a `forgot-password`/`check-reset-code`/`reset-password`.
- Mapeo de errores backend (código inválido→rebote al paso 2, 429,
  sin conexión, email no registrado → mismo 200 genérico del backend).
- El link "Reenviar" llamando al endpoint real.

## Verificación del ciclo

`flutter analyze` limpio · suite completa verde · `revisor-ui` critica
el wizard antes de tu revisión visual · spec en `design-system.yaml`
tras aprobación.
