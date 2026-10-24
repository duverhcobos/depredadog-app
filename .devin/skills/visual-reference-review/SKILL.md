---
name: visual-reference-review
description: Cómo analizar referencias visuales del usuario (screenshots, mocks, capturas de otras apps) — cuestionar cada elemento, decidir qué queda/qué se cambia/qué se rechaza contra el design system, y pedir sign-off ANTES de implementar
triggers:
  - user
  - model
---

Cuando el usuario pega una captura/mock/referencia ("analiza esta screenshot", "así como esta
app", "que se vea así"), la referencia es **punto de partida, no spec**. El trabajo es decidir
qué queda, qué se adapta y qué se rechaza — para quedarnos con la mejor versión **acorde al
design system** (`Design/design-system.yaml` es la fuente de verdad; ver skills
`frontend-design`, `ui-design-standard`, `summary-drilldown`).

**Primero confirmar intención**: si solo la muestra ("es una referencia, no hagas nada"), se
analiza y NO se implementa hasta que el usuario lo pida explícitamente.

## Proceso

### 1. Leer la referencia — qué intenta comunicar

Identificar qué problema resuelve cada elemento: ¿jerarquía? ¿escaneo? ¿afordancia? Separar la
**idea** ("destacar el total") de la **ejecución** (ese card gigante con 5 badges).

### 2. Mapear contra el design system

Para cada elemento preguntar:

- ¿Existe ya un componente/patrón que hace esto? (cards, chips, pills, heroes, `summary_drilldown`)
- ¿Usa tokens de la paleta `app*` o introduce un color/estilo nuevo que necesitaría
  aprobación y registro en el yaml?
- ¿Calza con el flat 2D / formas curvas / espacios negativos del `visual_language`?

### 3. Cuestionar la semántica — el filtro más importante

Las referencias suelen tener decoración disfrazada de dato. Interrogar cada número, badge,
filtro y barra:

- **¿El número miente?** Un "% recuperado" o una barra a mitad cuando la data real da 0 —
  la semántica debe medir lo que dice medir (caso real: barras a 50% cuando la fracción
  real era otra → corregido a la fracción medida).
- **¿El filtro esconde datos?** Un scope de período en un nivel de resumen hace que el KPI
  deje de ser el total real ("Octubre" ocultaba ítems viejos pendientes — rechazado).
- **¿El label es honesto?** Un "$170.000" pelado no dice si es bruto, pagado o pendiente →
  "queda $X".
- **¿La affordance existe de verdad?** Un chevron/botón que no navega a nada es mentira visual.

### 4. Clasificar — qué queda, qué se cambia, qué se rechaza

| Decisión | Criterio |
|---|---|
| **Queda** | Resuelve un problema real Y calza tokens/patrones (o adapta uno existente) |
| **Se cambia** | La idea es buena pero la ejecución rompe paleta, semántica o convenciones — adaptar con tokens/patrones propios |
| **Se rechaza** | Miente con la data, esconde información, o es ornamento que compite con el contenido |

Para cada "se cambia"/"se rechaza" **explicar el porqué** — no descartar en silencio.

### 5. Sign-off antes de implementar

Presentar la tabla queda/cambia/rechaza al usuario y esperar su OK. Las decisiones con
alternativas reales van por `ask_user_question` (regla del proyecto) — ej. "¿este hero en
acento suave o en blanco?".

### 6. Registrar lo decidido

Si la iteración produce un componente/patrón nuevo o una corrección de la referencia que vale
para el futuro → documentarla en el yaml en la misma iteración (skill `design-system-docs`);
si nace una convención transversal, candidata a `components.*` + `continuity_rules`.

## Anti-patrones a no repetir

- Copiar la referencia literal con valores hardcodeados fuera de `AppColors`/tokens.
- Implementar sin sign-off cuando el usuario solo pidió análisis.
- "Mejoras" que agregan ruido: más badges, más iconos, más colores compitiendo — la dirección
  PCalientes gasta la audacia en UN elemento firma por pantalla/sección.
