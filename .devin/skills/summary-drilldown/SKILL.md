---
name: summary-drilldown
description: Patrón visual "headline + drill-down" (resumen → detalle) — convención obligatoria para páginas/secciones que resumen una colección con detalle detrás. El spec con tokens se registra en Design/design-system.yaml → components.summary_drilldown al aprobarse la primera sección
triggers:
  - user
  - model
---

Patrón visual **"headline + drill-down"** de Pronósticos — ratificado por el usuario como
convención para TODOS los diseños y rediseños futuros: *"que se conserve ese estilo de ui/ux"*.
Este skill es la guía de aplicación; el spec completo con tokens se registra en
`Design/design-system.yaml` → `components.summary_drilldown` cuando se apruebe la primera
sección de este tipo (ver skill `design-system-docs`).

## Cuándo aplica

Páginas o secciones que **resumen una colección con detalle detrás**: fichas con historial,
módulos con KPI + listado, resúmenes de cuenta. La idea en una frase: **la respuesta primero
(KPI), el desglose después, el detalle completo un nivel más abajo**.

NO aplica a pantallas de captura de datos ni flujos paso a paso.

## Estructura (de arriba hacia abajo)

1. **Hero KPI** — una sola respuesta en grande: label corto + métrica principal 26px w800
   (Σ/count **real del filtro**, no de las filas visibles) + métrica secundaria opcional.
   - Nivel **sección/ficha**: fondo `appAccentSoft` (acento suave), tile `appAccent` +
     icono de marca, aro decorativo α~0.35 cortado al borde derecho, monto en color primario.
   - Nivel **página/módulo**: el header de marca sigue siendo la firma visual.
2. **Cards agrupadas** — blancas r14 borde `appBorder`, una por categoría. Header:
   icono en tile `appAccentSoft` + OVERLINE caps 11 w700 + subtítulo 13 secondary +
   badge `NN` zero-padded con el `meta.total` real.
3. **Filas-pill** — `appSurface` r10: icono-avatar en círculo con el **color semántico del
   estado** (el "avatar" del chip — mismo mapa de colores que el chip de estado del dominio), título w600 +
   detalle 12 secondary, trailing: dato principal (monto `appAmberDeep` w800) + chevron.
4. **"Ver todos/todas"** — link + botón círculo `appAccent` al listado completo (con filtro
   sembrado si la sección vive en una ficha). Presente aunque la lista esté vacía.

## Reglas que no se negocian

- **Progressive disclosure**: nunca mostrar todo — 3–5 filas + "Ver todos"; el badge dice el
  total REAL (`meta.total`), no las filas pintadas; cada pill abre su ficha (chevron obligatorio).
- **Sin filtros de período en el nivel resumen** — un headline responde el total real; un chip de
  mes en el KPI esconde deuda/datos fuera de la ventana (un chip de período en el KPI se
  rechazó por esto; la vista por período vive en el módulo, si existe).
- **Semántica honesta**: si parece información, ES información — barras de progreso = fracción
  real medible, % con denominador honesto (y se oculta sin base, nunca inventado), montos con
  label cuando son ambiguos ("queda $X"), estados terminales como evidencia atenuada (0.55).
- **Navegación**: el drill-in usa rutas hijas del mismo branch + `context.push` — el back siempre
  regresa al origen del resumen (ver skill `navigation-routing`).

- **Listado largo de módulo**: cuando el drill-down vive a nivel página con scroll único bajo el
  header de marca (convención — todo el contenido rueda junto, sin caja con scroll propio), el botón
  "volver arriba" es `AppScrollTopButton` (su spec se registra en el yaml como
  `scroll_top_button` al implementarse — ver skill `ui-design-standard` para esquina libre
  vs. apilado sobre FAB).

## Referencia de implementación

La primera sección resumen→detalle que se implemente fija el molde
(`features/<modulo>/presentation/widgets/<seccion>_section/`): widget hero + card header
compartido (overline + badge), filas-pill y el link "Ver todos". Esa primera implementación
queda como referencia canónica de esta guía.
