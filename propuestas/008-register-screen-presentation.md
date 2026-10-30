# Propuesta 008: Pantalla `/register` — FASE PRESENTACIÓN (sin integración)

Primera fase del `screen-first-workflow` para `POST /auth/register`: solo la
capa de presentación con submit SIMULADO (como hizo verify-email en §005) —
el usuario aprueba lo que ve en el emulador antes de conectar el endpoint.

**Hechos del contrato backend (ya vigente — propuesta backend 004 aplicada):**

- `POST /auth/register` (201, throttle 3/min): `email*`, `password*` (8-72),
  `firstName*` + `firstLastName*` (**nombre LatAm en 4 campos** —
  `secondName?` + `secondLastName?` opcionales), `phone?` (≤20),
  `referralCode?`, `marketingOptIn?`, `deviceFingerprint?`, `platform?`.
- Éxito → usuario `pending_verification` + código enviado → la navegación
  real será a `/verify-email` (ya integrada — el flujo cierra solo).
- Errores de negocio (fase 2): 409 email duplicado, 400 referido inválido,
  400 validación, 429.

**Decisiones ya tomadas por el usuario:**

| Decisión | Resultado |
|---|---|
| Nombre | **4 campos**: Primer nombre*, Segundo nombre (opc), Primer apellido*, Segundo apellido (opc) |
| Teléfono | **Opcional** |
| Código de referido | **Fuera del MVP** — no va en el formulario |
| marketingOptIn | **Sin checkbox** (false por defecto) — registro lo más sencillo posible |

**Pendientes de la encuesta (decisión embebida marcada):**

- Confirmar contraseña: propuesta **sí** (detecta typos sin roundtrip).
- Header: propuesta **marca compacta** (~110px) — el form es largo.

## Diseño de la pantalla

```
┌─────────────────────────────┐
│ ← (back fijo, a /login)     │
│                             │
│   [imagotipo ~110px]        │
│   ÚNETE A LA MANADA         │  ← headline, misma voz que login
│   Crea tu cuenta y pide     │  ← subtítulo gris
│   algo salvajemente bueno   │
│                             │
│   Primer nombre *           │  ← text, capitalized
│   Segundo nombre (opcional) │
│   Primer apellido *         │
│   Segundo apellido          │
│   (opcional)                │
│   Correo electrónico *      │  ← email keyboard
│   Teléfono (opcional)       │  ← phone keyboard
│   Contraseña *              │  ← ojo + hint "Mínimo 8"
│   Confirmar contraseña *    │  ← ojo
│                             │
│   [ Crear cuenta ]          │  ← botón primario mostaza
│                             │
│   ¿Ya tienes cuenta?        │
│   Inicia sesión  → /login   │
└─────────────────────────────┘
```

- **Estructura**: scroll único (SingleChildScrollView) con back fijo arriba —
  misma solución que verify-email (el teclado ya taparía la mitad del form).
- **Los 4 campos de nombre**: dos pares — los requeridos sin marca y los
  opcionales con "(opcional)". Segundo nombre/apellido pueden quedar vacíos.
- **Autofill**: `AutofillGroup` con hints `username`/`newPassword` — al
  integrar se decide el `shouldSave` (la carrera modal-vs-teclado del OTP
  aplica igual que en login→verify).
- **Validación local (Formz)**: email formato, password ≥8 + match con
  confirm, primer nombre/apellido no-blank; teléfono opcional sin formato
  estricto (el server valida longitud).
- **Loading simulado**: ~800ms delay → éxito. Convención ya aprobada:
  spinner dentro del botón + `IgnorePointer` sobre el resto (sin atenuar).
- **Éxito simulado**: navega a `/verify-email` con el email tipeado — el
  usuario ve el flujo completo real (la pantalla de verify ya funciona).

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/features/auth/presentation/screens/register_screen.dart` | **Nuevo** — estructura como login (clase + vista + BlocProvider) |
| `lib/features/auth/presentation/widgets/register_form_fields.dart` | **Nuevo** — campos + validación Formz |
| `lib/features/auth/presentation/cubit/register_cubit.dart` + `register_state.dart` | **Nuevo** — submit simulado (delay→success→navegar) |
| `lib/features/auth/presentation/inputs/register_inputs.dart` | **Nuevo** — Formz: NameInput (no-blank), PasswordInput, ConfirmPasswordInput, EmailInput, PhoneInput (opcional) |
| `lib/core/routes/app_router.dart` | Registrar `/register` con slideUp (constante ya existe en AuthGuard) |
| `lib/features/auth/presentation/screens/login_screen.dart` | Link "Regístrate" → `context.push(registerRoute)` (reemplaza toast comingSoon) |
| `lib/l10n/app_es.arb` + `flutter gen-l10n` | ~20 claves nuevas (título, subtítulo, labels, hints, errores, CTA) |
| `Design/design-system.yaml` | spec `register` + bump de versión tras aprobación visual |
| `test/features/auth/presentation/cubit/register_cubit_test.dart` | **Nuevo** — submit inválido/éxito simulado |
| `test/features/auth/presentation/screens/register_screen_test.dart` | **Nuevo** — render, errores visibles, navegación simulada |

## Interacciones clave (a evaluar por revisor-ui)

- Ojo de visibilidad independiente en contraseña y confirmar.
- Teléfono: teclado numérico sin prefijo (+57 no se pinta — el DTO acepta
  cualquier string ≤20).
- Errores bajo campo tras intento de submit (patrón login), no en vivo.
- Back arriba fijo → `/login` (y el "Inicia sesión" del footer igual).
- Hint de contraseña bajo el campo: "Mínimo 8 caracteres".

## Orden de aplicación

1. inputs Formz → cubit+state → widgets → screen → router + link login.
2. `app_es.arb` → `flutter gen-l10n`.
3. Tests cubit + screen → `flutter analyze` + `flutter test`.
4. **revisor-ui** critica código+capturas → correcciones → emulador para
   aprobación visual → spec en design-system.yaml → commit.
