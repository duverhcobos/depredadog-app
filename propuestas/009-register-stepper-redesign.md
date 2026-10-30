# Propuesta 009: `/register` en 3 pasos con Stepper — FASE PRESENTACIÓN

Rediseño de la pantalla aprobada en 008: el usuario reportó que 8 inputs en
una sola pantalla se sienten densos. Se parte el formulario en **3 pasos**
con un stepper visual arriba. Sigue siendo fase presentación (submit
simulado → `/verify-email`).

**Decisiones del usuario:**

| Decisión | Resultado |
|---|---|
| Paso 1 | Datos personales: 4 campos de nombre + **teléfono** |
| Paso 2 | Cuenta: correo + contraseña + confirmar |
| Paso 3 | **Revisión de datos** (sin inputs — resumen + "Crear cuenta") |
| Marca | **Sin imagotipo** en los pasos — solo flecha + stepper + título |
| Stepper | Indicador arriba de los inputs, muestra el paso actual |
| Retroceso entre pasos | **Botón secundario "Atrás"** junto a Continuar (pasos 2-3) |
| Flecha superior | **Siempre sale a /login** (abandonar registro) — no retrocede pasos |
| Back nativo Android | **Retrocede un paso** (convención wizard); paso 1 → sale |
| Teclado auto | **Nunca abre solo** — solo al tocar campo o al fallar validación (foco al primer inválido) |
| Teléfono | **Solo celular colombiano**: 10 dígitos iniciando en 3; input solo dígitos |
| Nombres/apellidos | **Solo letras** (con tilde/ñ/ü) + espacio + apóstrofe — compuestos latinos OK ("De la Cruz", "O'Neil"); **sin guion**; filtro al teclear + validación (decisión del usuario) |
| Errores de campo | **Genéricos** (decisión del usuario): "Teléfono incorrecto", "Correo incorrecto", "Contraseña incorrecta" — nunca revelan la regla |

## Estructura por paso

```
PASO 1 "Cuéntanos quién eres"      PASO 2 "Tu correo y tu llave"    PASO 3 "Todo listo, {nombre}"
┌─────────────────────────┐        ┌─────────────────────────┐      ┌─────────────────────────┐
│ ←  (●)───(○)───(○)      │        │ ←  (✓)───(●)───(○)      │      │ ←  (✓)───(✓)───(●)      │
│     Datos  Cuenta Revis.│        │     Datos  Cuenta Revis.│      │     Datos  Cuenta Revis.│
│                         │        │                         │      │                         │
│ Cuéntanos quién eres    │        │ Tu correo y tu llave    │      │ Todo listo, Luis        │
│                         │        │                         │      │ Revisa que todo esté ok │
│ Primer nombre *         │        │ Correo electrónico *    │      │ ┌─────────────────────┐ │
│ Segundo nombre (opc)    │        │ Contraseña *  (ojo)     │      │ │ Nombre   Luis Rojas │ │
│ Primer apellido *       │        │   "Mínimo 8 caracteres" │      │ │ Correo   luis@t.com │ │
│ Segundo apellido (opc)  │        │ Confirmar contraseña *  │      │ │ Teléfono 300 123... │ │
│ Teléfono (opc)          │        │                         │      │ └─────────────────────┘ │
│                         │        │                         │      │                         │
│ [ Continuar ]           │        │ Atrás  [ Continuar ]    │      │ Atrás [ Crear cuenta ]  │
│ ¿Ya tienes cuenta? ...  │        │ ¿Ya tienes cuenta? ...  │      │ ¿Ya tienes cuenta? ...  │
└─────────────────────────┘        └─────────────────────────┘      └─────────────────────────┘
```

- **Stepper** (widget nuevo `register_stepper.dart`): 3 círculos numerados +
  líneas conectoras + labels "Datos"/"Cuenta"/"Revisión". Actual = círculo
  lleno mostaza con el número; completado = círculo tenue con `✓`; pendiente
  = círculo outline gris con número. Solo visual (no toca pasos — la
  navegación es por flecha/botones).
- **Navegación hacia atrás (refinamiento — decisión del usuario)**: hay DOS
  vías con semántica distinta:
  - **Flecha superior** = abandonar el registro → `/login` en CUALQUIER
    paso (su rol es "salir de la pantalla", igual que en login/verify). Al
    salir se pierde lo tipeado (vive en memoria — aceptado).
  - **Botón secundario "Atrás"** (`TextButton` a la izquierda del botón
    primario, solo en pasos 2-3) = retrocede un paso sin abandonar.
  - **Back nativo Android** (`PopScope`) = convención de flujos por pasos:
    retrocede un paso en 2-3, sale a `/login` en paso 1.
- **Transición entre pasos**: `AnimatedSwitcher` ~250ms (fade + slide leve).
- **Contenido por paso**: cada paso es su propio bloque dentro del
  `SingleChildScrollView` existente — mismos `CustomTextField`, mismos
  controllers/focus (el State ya los posee — no se recrean).
- **Título por paso**: paso 1 "Cuéntanos quién eres" · paso 2 "Tu correo y
  tu llave" · paso 3 "Todo listo, {firstName}" (personaliza con el nombre
  tipeado — confirma visualmente que quedó bien) + subtítulo "Revisa que
  todo esté bien".
- **Tarjeta de revisión** (paso 3): `Container` con surface + borde sutil,
  filas label→valor: **Nombre** (compone los 4 campos no-vacíos unidos por
  espacio), **Correo**, **Teléfono** (o "Sin teléfono" si vacío). Sin
  contraseña — nunca se muestra.
- **Botones de acción**: fila `[Atrás | Continuar/Crear cuenta]` — "Atrás"
  es `TextButton` (el primario siempre domina), solo visible en pasos 2-3;
  en paso 1 el primario va a todo el ancho. Bloqueados durante
  `isInProgress` igual que el resto de controles.
- **Footer**: "¿Ya tienes cuenta? Inicia sesión" persistente en los 3 pasos.
- **Validación por paso**: "Continuar" en paso 1 solo valida
  firstName/firstLastName/phone; en paso 2 solo email/password/confirm.
  Errores bajo campo + foco al primer inválido DEL PASO (no navega a otro
  paso con error oculto — el error está donde se ve).

## Cambios en el cubit/state

- `RegisterState.currentStep` (int 0-2). `isValid` sigue global.
- `nextStep()`: valida SOLO los campos del paso actual → inválido: flags de
  error de ese paso + `failure` (foco + toast como hoy) → válido:
  `currentStep++` + status `initial`.
- `prevStep()`: `currentStep--` (sin re-validar).
- `submit()` (ahora `submitReview()` o mismo nombre, solo desde paso 3):
  re-valida todo (por seguridad) → delay simulado → `success` → la pantalla
  navega a `/verify-email` igual que hoy.
- Los `*Changed` no cambian (ya resetean status/authFailure).

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `widgets/register_stepper.dart` | **Nuevo** — indicador 3 pasos |
| `widgets/register_step_content.dart` | **Nuevo** — título+subtítulo por paso y tarjeta de revisión (o separar `register_review_card.dart` si el archivo supera umbral) |
| `widgets/register_form_fields.dart` | Se parte en 3 secciones por paso (o un widget `register_step_fields.dart` por paso si queda >300 líneas — file-size-refactoring) |
| `screens/register_screen.dart` | Reestructura: flecha + stepper + AnimatedSwitcher + footer; header/imagotipo/título se retiran |
| `cubit/register_cubit.dart` + `register_state.dart` | `currentStep`, `nextStep()`, `prevStep()`, validación por paso |
| `app_es.arb` | Claves: labels de pasos, títulos/subtítulos, "Continuar", "Atrás", labels de revisión, "Sin teléfono"; quitar las que queden huérfanas (headline/subtitle viejos) |
| tests cubit + screen | Actualizar + casos nuevos: nextStep valida por paso, back entre pasos, revisión muestra datos compuestos, submit→verify |
| `Design/design-system.yaml` | Spec del stepper + pantalla + bump tras aprobación visual |

## Verificación (padre, en emulador)

1. Paso 1 → "Continuar" vacío → errores solo en paso 1 (nombre/apellido),
   foco al primero
2. Paso 1 válido → transición a paso 2 → stepper muestra 2
3. "Atrás" en paso 2 → vuelve a paso 1 CON los datos tipeados intactos;
   en paso 1 no existe el botón
4. Paso 2: correo malo → error; contraseñas distintas → mismatch
5. Paso 3 → tarjeta con nombre compuesto + correo + teléfono/"Sin teléfono"
6. "Crear cuenta" → spinner → `/verify-email` con el correo
7. Flecha en CUALQUIER paso → `/login` (abandona el registro)
8. Back nativo en pasos 2-3 → paso anterior; en paso 1 → `/login`
