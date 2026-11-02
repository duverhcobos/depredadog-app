# Propuesta 013: botón Google en `/register` paso 1 — FASE PRESENTACIÓN

El botón de Google existía solo en login; el usuario pidió que también
aparezca en el registro antes de integrar `/auth/google`. Cambio de
presentación puro — el botón compartido sigue mostrando el toast provisional
"Disponible próximamente" hasta la integración real.

**Decisiones del usuario:**

| Decisión | Resultado |
|---|---|
| Ubicación | **Solo paso 1** — Google reemplaza el registro entero, no lo complementa; en pasos 2-3 el usuario ya está comprometido con el formulario |
| Posición | Tras el primario "Continuar", con el mismo patrón de login: divisor "o continúa con" → `GoogleSignInButton` → footer |
| Widget | Reusar `GoogleSignInButton` compartido — nada de duplicar |
| Copy del botón | **"Continuar con Google"** — recomendación oficial de Google para superficies que cubren registro + login (el usuario había elegido "Ingresar" primero; el revisor-ui señaló el punto y el usuario cambió a "Continuar"). La clave `loginGoogleButton` es compartida — cambia en login y register a la vez |

## Implementación

- `register_screen.dart`: bloque condicional por `state.isFirstStep` dentro
  del scroll, después de la fila de acción primaria:
  `BlocBuilder(isFirstStep/isInProgress) → AnimatedSize → IgnorePointer
  (isInProgress) → Column[Row(Divider+Text+Divider), 24, GoogleSignInButton, 32]`.
- Pasos 2-3: `SizedBox.shrink` — el bloque no existe.
- **AnimatedSize** (250ms easeOut, topCenter): sin él el bloque aparecía/
  desaparecía en seco y el footer saltaba ~116px mientras el cuerpo aún
  animaba la transición de paso (hallazgo MENOR del revisor-ui).
- **32px** de botón a footer (no 24): paridad literal con login — el footer
  necesita respiro extra tras el bloque social outlined (hallazgo MENOR).
- `IgnorePointer(ignoring: isInProgress)` espejo de login — apariencia
  intacta, convención del proyecto.

## Tests

- Paso 1: `findsOneWidget` para "o continúa con" y "Continuar con Google";
  el único `Image` del paso es la G oficial (asset `google_g.png`) — la
  aserción "sin imagotipo" se reescribió para exigir eso en vez de
  `findsNothing` global.
- Pasos 2-3: `findsNothing` para ambos textos.
- `tapPrimary`/`tapBackStep`: `ensureVisible` + `pumpAndSettle` — con el
  bloque nuevo el paso 1 creció y un solo `pump()` dejaba la animación de
  scroll a medio camino: el hit test desincronizaba y el tap caía fuera del
  clip del viewport.

## Documentos tocados

- `pendientes/006-google-oauth.md`: el botón ahora vive en 2 superficies;
  al ser widget compartido, ocultarlo en prod resuelve ambas.
- `Design/design-system.yaml`: spec de `screens.register` + `google_sign_in_button`,
  version bump + changelog.
