# Crítica de diseño estricta — convención del proyecto

Cada pantalla/widget nuevo (o cambio visual relevante) pasa por una crítica de
diseño ejecutada por el subagente `revisor-ui` **antes** de mostrarla al
usuario. El crítico actúa como diseñador/a de interfaces senior con mentalidad
de abogado del diablo: su trabajo es **encontrar problemas, no validar** — una
pantalla sin hallazgos es la excepción, no la norma.

Esto complementa al agente `revisor` (que audita SOLID/arquitectura):
`revisor-ui` audita lo que se **ve**, `revisor` audita cómo está **escrito**.

## Cuándo corre

- Al terminar la fase de presentación de una pantalla nueva (screen-first:
  después del implementador, **antes** de la aprobación visual del usuario).
- Tras cualquier cambio visual en una pantalla existente (layout, componentes,
  colores, estados).
- Bajo demanda si la sesión principal o el usuario lo piden.

## Loop del gate

```
implementación → revisor-ui critica (código + capturas)
  → sesión corrige CRITICO + IMPORTANTE
  → re-crítica acotada solo a lo corregido
  → usuario revisa en emulador → aprueba → analyze/test → commit
```

Hallazgos MENOR/INFO no bloquean, pero se reportan al usuario junto con la
pantalla — él decide si se ajustan o quedan anotados.

## Evidencia que recolecta el agente

1. **Código**: la screen + sus widgets + cubit/state (estados que puede
   mostrar), `Design/design-system.yaml` (spec de la pantalla si existe),
   `AppTheme`/`AppColors`, y **una pantalla hermana** (ej. Login vs
   VerifyEmail) para juzgar consistencia de familia.
2. **Capturas del emulador**: `adb shell screencap` → `adb pull` → leer el PNG
   (la herramienta read muestra imágenes). Capturar cada estado alcanzable:
   inicial, error de validación, loading, cooldown/estados temporizados,
   teclado abierto si la pantalla tiene campos. La sesión debe indicar en la
   tarea **cómo se llega a la pantalla** (ej. "splash redirige a /verify-email"
   o "en login, tap en Regístrate").
3. **Tema**: la app del MVP corre solo tema **oscuro** — la crítica se hace
   sobre ese tema únicamente (no exigir variante clara).

## Rúbrica de crítica

Cada categoría se evalúa con evidencia (captura o línea de código). Sin
evidencia, no hay hallazgo.

### 1. Jerarquía y primer vistazo
- ¿A dónde va el ojo en el primer segundo? ¿Es lo correcto (acción primaria o
  elemento firma) o compite con ruido?
- ¿Hay UN elemento firma (frontend-design) o varios efectos peleando?
- ¿El headline se entiende solo, o necesita leer el subtítulo para saber dónde
  estás?

### 2. Espaciado y alineación
- ¿Respeta la escala `8/12/16/24/32` (ui-design-standard) o hay valores
  arbitrarios/ritmo roto?
- ¿Los bordes izquierdo/derecho de bloques y botones están alineados entre sí?
- ¿Algún elemento "flota" sin ancla? (caso real: botón volver dentro de una
  columna verticalmente centrada — quedó a media pantalla en vez de fijo
  arriba).

### 3. Tipografía
- ¿Roles correctos (display con carácter en títulos, cuerpo legible en resto)
  o tamaños arbitrarios?
- ¿El copy largo tiene ancho de línea legible (~40-60 chars) y line-height
  suficiente?

### 4. Color y contraste
- ¿Todo sale de `colorScheme`/tokens, cero hex suelto en la pantalla?
- ¿El texto secundario se lee cómodo sobre el fondo negro (MVP solo oscuro)?
- ¿El color es semántico? (error ≠ branding, primary = acción/éxito).

### 5. Estados completos
- ¿Están diseñados TODOS los estados que el state puede emitir (inicial,
  loading, error, éxito, vacío, disabled, cooldown) — o solo el happy path?
- ¿Loading reemplaza el CTA con spinner según patrón, no lo deja deshabilitado
  con rueda adentro?

### 6. Affordances y navegación
- ¿Lo tappable parece tappable y lo no-tappable no miente (affordance falsa =
  rechazo)?
- ¿Volver es obvio? Flecha visible + back nativo cubiertos.
- ¿Hit areas ≥ 44-48dp en todo lo interactivo?

### 7. Teclado, scroll y bordes
- ¿El teclado no tapa el campo activo ni el CTA (scroll/padding correctos)?
- ¿`SafeArea` respetada (nada bajo status bar ni gesture bar)?
- ¿Contenido que excede alto → scroll, no overflow?

### 8. Consistencia de familia
- ¿Header, CTA primario, feedback (Toast, no SnackBar), patrones de campos
  coinciden con la pantalla hermana de referencia?
- ¿Reutiliza componentes (`CustomTextField`, patrones establecidos) o
  reinventó?

### 9. Copy
- ¿Habla el idioma del dominio, voz activa, sin jerga técnica?
- ¿Errores dicen qué pasó y qué hacer, no vagos?
- ¿Todo localizado (cero literal suelto)?

### 10. Accesibilidad básica
- Contraste suficiente en tema oscuro, targets de toque, tooltips semánticos
  en iconos accionables.

## Reglas del crítico

- **Evidencia obligatoria**: cada hallazgo cita captura o `archivo:línea`.
- **Anclado a la rúbrica**: no opiniones de gusto personal — cada crítica se
  justifica con la rúbrica, el design-system.yaml o una pauta de usabilidad
  reconocida (Nielsen, Material HIG).
- **Honestidad sobre severidad**: distinguir "está mal" (rompe jerarquía,
  miente, incompleto) de "podría ser mejor" (INFO).
- **No edita código**: reporta; la sesión principal decide y corrige.
- **Estados no alcanzables por taps**: se critican desde el código (ej. un
  loading de 600ms difícil de cazar por captura).
- **Dejar el emulador limpio**: al terminar, volver a la pantalla de entrada o
  anotar dónde quedó.

## Formato de reporte

```
[SEVERIDAD] captura_o_archivo:línea — problema observado
  Rúbrica: <categoría y punto violado>
  Sugerencia: <corrección concreta>
```

Severidades: `CRITICO` (bloquea mostrar al usuario — rompe jerarquía, miente,
falta un estado, bug visual), `IMPORTANTE` (degrada la experiencia o rompe
consistencia), `MENOR` (pulido), `INFO` (idea/oportunidad).

Cierre: conteo por severidad + veredicto
`APROBADO / APROBADO CON OBSERVACIONES / REQUIERE CORRECCIONES`.
