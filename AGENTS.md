# Instrucciones del Proyecto — Depredadog App (Flutter)

El detalle de convenciones, arquitectura y workflows de este proyecto vive en skills bajo `.devin/skills/`, no en este archivo — cada skill cubre una sola responsabilidad y se invoca solo cuando es relevante, para no cargar contexto innecesario en cada sesión.

> Estado actual: bootstrap del core implementado (environment, DI, network, storage, router+guard, tema condimentos, i18n) — propuesta 001-app-bootstrap. Pantallas aprobadas en presentación: **login** (§003) y **verify-email** (§005 — 6 casillas OTP, cooldown de reenvío, ícono de marca SVG; submit/reenvío aún simulados). Welcome eliminado; splash → /login sin sesión; imagotipo con Hero splash→login. **MVP solo tema oscuro** (`ThemeMode.dark` fijo). **Feedback efímero = `AppToast`/fluttertoast en toda la app** (SnackBar retirado — decisión del usuario). **Gate de diseño**: subagente `revisor-ui` critica cada pantalla (código + capturas) antes de la revisión visual del usuario. Siguiente: integración de `/auth/login` contra `../pcalientes_backend` (screen-first: un endpoint por ciclo).

## Reglas mínimas siempre vigentes

- **Idioma de respuesta: español neutro latinoamericano** — tuteo estándar ("tienes", "puedes", "revisa"), SIN voseo rioplatense ni formas de España.
- **Framework:** Flutter, Clean Architecture + S.O.L.I.D. Package: `depredadog_app`.
- **Commits sin trailer de herramienta** — no agregar `Generated with ...` ni `Co-Authored-By` al mensaje; solo el texto del commit.
- **Nunca editar archivos fuente directamente** para implementar funcionalidad o lógica de negocio: ver skill `code-proposals` antes de escribir/modificar código (excepción: correcciones triviales de un solo archivo).
- **OS de desarrollo**: Windows — los comandos de ejemplo deben ser compatibles con el terminal del agente.
- **Producto: app móvil** consumidora del backend NestJS `../pcalientes_backend` (`:3000`) — único cliente esperado, sin panel web. Tratar todo cambio con rigor de código productivo — ver skill `environments-secrets` **siempre** que se toquen entornos, URLs, tokens o certificados.
- **Decisiones con opciones, siempre**: cuando una tarea llegue a un punto de decisión con alternativas, presentar las opciones como pregunta de elección con trade-offs breves — no decidir unilateralmente ni pedir confirmación abierta.

## Índice de skills

| Skill | Cuándo usarla |
|-------|---------------|
| `flutter-architecture` | Antes de crear un archivo/feature nueva — confirmar el stack real y la estructura de carpetas Feature-First |
| `solid-clean-architecture` | Al escribir o revisar código — reglas SOLID, separación de capas, qué NO hacer |
| `environments-secrets` | Al tocar variables de entorno, URLs, tokens, certificados o cualquier cosa relacionada con sesión/seguridad |
| `i18n-workflow` | Al agregar o modificar cualquier texto visible al usuario |
| `ui-design-standard` | Al crear o modificar una pantalla/widget — theming, espaciado, componentes reutilizables, patrones de estructura |
| `file-size-refactoring` | **Siempre** al crear o modificar código — umbrales de tamaño de archivo y cuándo/cómo extraer widgets |
| `bloc-patterns` | Al escribir o revisar UI con estado — `context.read`/`watch`/`select` vs `BlocBuilder`/`BlocListener`/`BlocConsumer` |
| `frontend-design` | Al diseñar o rediseñar UI con impacto visual — dirección estética distintiva |
| `summary-drilldown` | Al diseñar una página/sección que resume una colección con detalle detrás — patrón "headline + drill-down" |
| `visual-reference-review` | Cuando el usuario pega una captura/mock/referencia visual — analizar, decidir qué queda/cambia/rechaza, sign-off antes de implementar |
| `testing-workflow` | Al escribir tests o correr `flutter analyze`/`flutter test` |
| `code-proposals` | **Siempre** que se vaya a proponer un cambio de código — formato y reglas del archivo en `propuestas/` |
| `production-checklist` | **Siempre** antes de dar por terminado un cambio |
| `navigation-routing` | Al tocar rutas/pantallas — go_router: constantes en el guard, segmentos relativos en hijos, push vs go |
| `release-build` | Antes de generar APK/AAB release — permisos, --dart-define por entorno, firma y versionado |
| `pendientes-produccion` | Al crear/consultar pendientes pre-producción — carpeta `pendientes/` propia del repo (los del backend van en la suya) |
| `design-system-docs` | Tras cualquier cambio visual — cómo actualizar `Design/design-system.yaml` (version, spec, changelog) |
| `new-feature-checklist` | Al agregar un módulo/feature nuevo — orden exacto de archivos del dominio a la pantalla |
| `screen-first-workflow` | **Workflow de desarrollo por pantallas** — fase 1: solo presentación sin conectar (aprobación visual); fase 2: integración un endpoint a la vez (pruebas → aprobación → commit → siguiente) |
| `token-saving-tools-policy` | Al explorar el código — cuándo leer directo vs. usar el grafo codebase-memory, batching |
| `app-icons` | Al tocar íconos de launcher o el splash nativo — ícono por modo, capas adaptativas, `mipmap-night-*`, procedimiento de actualización |
| `emulator-health` | Cuando el emulador va lento/congelado, la app no levanta o `adb` no responde — diagnóstico de RAM del host, daemon Gradle, aceleración WHPX y cold boot sin snapshot |
| `ui-design-critique` | Tras implementar una pantalla/widget, **antes** de mostrarla al usuario — rúbrica de crítica de diseño estricta que ejecuta el agente `revisor-ui` (código + capturas) |

Si una instrucción parece faltar acá, buscarla primero en `.devin/skills/` antes de asumir que no existe. En la raíz solo viven los esenciales: `AGENTS.md` y `README.md`.

## Flujo de desarrollo con subagentes

El proyecto tiene tres subagentes custom en `.devin/agents/`. **Usarlos siempre que aplique** — no implementar propuestas ni auditar código directamente en la sesión principal:

| Subagente | Rol | Cuándo delegarle |
|-----------|-----|------------------|
| `implementador` | Aplica propuestas aprobadas al pie de la letra + `flutter analyze` + `flutter test` | Después de que la sesión principal redacte y el usuario apruebe una propuesta |
| `revisor` | Audita SOLID/convenciones — solo lee, no edita | Después de implementar, para verificar calidad del código resultante |
| `revisor-ui` | Critica el DISEÑO de pantallas (jerarquía, espaciado, estados, consistencia) leyendo código + capturas del emulador — solo reporta | Tras implementar una pantalla/widget, **antes** de la aprobación visual del usuario (ver `ui-design-critique`) |

### Flujo estándar para cambios no triviales

```
1. Sesión principal → diseña la propuesta en propuestas/
2. Usuario aprueba
3. Subagente "implementador" → aplica la propuesta
4. Subagente "revisor" → audita el resultado
5. Sesión principal → reporta resumen al usuario
```

La sesión principal **piensa y decide**; los subagentes **ejecutan y verifican**.
Correcciones triviales de un solo archivo no necesitan subagente.

**Desarrollo por pantallas (ver `screen-first-workflow`):** las features de UI se
construyen en dos fases — primero solo la capa de presentación (aprobación
visual del usuario), luego la integración domain/data **un endpoint a la vez**
(probar → aprobar → commit → siguiente endpoint).

### Cambios visuales/UX: crítica de diseño → usuario ve → verificar

Cuando el cambio es de UI visible (cards, pantallas, formularios), el orden es:

```
1. Propuesta + implementación
2. Subagente "revisor-ui" critica el diseño (código + capturas, skill
   ui-design-critique) → sesión corrige CRITICO/IMPORTANTE y re-critica
3. Se deja la app corriendo en el emulador para que el usuario LA VEA
4. SOLO cuando el usuario aprueba lo que ve → flutter analyze, flutter test,
   design-system yaml, commits
```

El implementador puede correr analyze/tests como sanity check propio, pero la
verificación completa y los commits esperan al OK visual del usuario.
