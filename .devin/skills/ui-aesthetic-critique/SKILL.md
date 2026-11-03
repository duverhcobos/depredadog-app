# Crítica estética — "¿se ve bonito?" — convención del proyecto

Cada pantalla/widget nuevo (o cambio visual relevante) pasa por una crítica
**estética** ejecutada por el subagente `revisor-estetico`, que corre **antes**
de `revisor-ui`. Responde la pregunta que el crítico técnico no cubre:
*¿esto se ve como un producto diseñado con intención, o como una plantilla
Flutter con el logo encima?*

Complementa, no se encima:

- `revisor-estetico` audita lo que se **siente** — dirección de arte,
  composición, personalidad de marca, apetito. Sus hallazgos son juicios de
  gusto **anclados a documentos de marca**, no opiniones libres.
- `revisor-ui` audita lo que está **bien hecho** — contraste, hit areas,
  alineación, tokens, estados.

## Cuándo corre

- Tras la implementación de la fase presentación de una pantalla nueva,
  **antes** de `revisor-ui` (la dirección se ajusta primero; pulir técnicamente
  un layout que luego se rediseña es trabajo perdido).
- Tras cambios visuales grandes en una pantalla existente.
- Bajo demanda.

## Loop del gate

```
implementación → revisor-estetico (¿se ve bien? ¿siente Depredadog?)
  → sesión aplica PULIDO alineado / consulta al usuario los de DIRECCIÓN
  → revisor-ui (técnico) → sesión corrige CRITICO+IMPORTANTE → re-crítica
  → usuario revisa en emulador → aprueba → design-system.yaml → commit
```

## Anclas obligatorias (sin ellas no hay hallazgo)

El gusto sin ancla es opinión personal — prohibido. Cada juicio debe citar
UNA de estas fuentes:

1. `Design/brand-brief.md` — identidad, tono, personalidad de Depredadog.
2. `Design/design-system.yaml` — dirección visual ya aprobada.
3. Skill `frontend-design` — los principios de dirección (elemento firma
   único, tipografía con carácter, complejidad calzada con la visión,
   "¿es una decisión para esta app o la produciría cualquier app?").
4. Referencias visuales/decisiones del usuario — lo que ya aprobó es el
   norte (ej. franja mostaza, imágenes flotantes, sin hamburguesa).
5. Comportamiento del dominio: es comida rápida — la pantalla debe
   **dar hambre y dar confianza**; un catálogo que no apetece es un defecto.

## Rúbrica estética

### 1. Primer impacto
- Si le mostraras la captura a alguien 1 segundo, ¿diría "app de comida
  con personalidad" o "app genérica"? ¿Transmite el negocio (perros,
  manada, hambre) o podría ser de seguros?
- ¿Hay UN elemento firma memorable (la franja, las imágenes flotantes) o
  la pantalla no se recuerda a los 10 minutos?

### 2. Composición y ritmo visual
- ¿El ojo fluye en el orden correcto? ¿Hay tensión/asimetría deliberada o
  todo cae en el "centro aburrido"?
- ¿El aire (espacio negativo) respira o sofoca? Un bloque denso pegado a
  otro se siente barato aunque esté "alineado".
- ¿Los tamaños relativos cuentan la jerarquía emocional? (El Depredador
  debe SENTIRSE el alfa, no solo tener un tag que lo dice.)

### 3. Personalidad de marca
- ¿La pantalla habla con la voz de Depredadog (depredador, manada, sin
  piedad) o con la voz neutra de Material?
- ¿El mostaza se usa como firma (pocos golpes, intencional) o se diluye
  decorando todo?
- ¿El copy tiene hambre y actitud? (taglines de la carta vs texto funcional).

### 4. Apetito y fotografía
- ¿Las imágenes dan hambre? Escala generosa, producto protagonista, sin
  distracciones. Una foto chiquita o cortada mata la venta.
- ¿Los PNGs flotan con intención o parecen "pegados por accidente"?

### 5. Intención vs. versión a medias
- Si la dirección es audaz (franja + offset), ¿la ejecución la lleva al
  máximo o quedó tibia? Una decisión audaz ejecutada a medias se ve peor
  que una sobria bien ejecutada.
- ¿Cada detalle parece decidido o hay cosas "que quedaron así"?

## Clases de hallazgo (distintas del crítico técnico)

```
[PULIDO] captura — oportunidad estética dentro de la dirección aprobada
  Ancla: <brand-brief / design-system / frontend-design / decisión usuario>
  Ajuste: <cambio concreto de bajo riesgo>
```

La sesión aplica PULIDO directamente si es barato y alineado (tamaño de
imagen, peso tipográfico, aire, proporción).

```
[DIRECCION] captura — propuesta que cambia la dirección aprobada
  Ancla: <fuente>
  Propuesta: <cambio> | Costo: <alto/medio/bajo> | Por qué mejoraría
```

DIRECCION **nunca** se aplica unilateralmente — la sesión lo presenta al
usuario como opciones y él decide (regla del proyecto).

## Reglas del crítico estético

- **Puede aprobar sin hallazgos.** "Se ve bien" es un veredicto válido —
  a diferencia del técnico, no caza problemas por deporte.
- **Toda crítica cita ancla + captura.** "Se siente apretado" sin decir
  por qué ni en qué se nota no es un hallazgo, es ruido.
- **Máximo ~5 hallazgos.** Priorizar lo que más cambia la impresión; una
  lista de 15 matiz estético es inaccionable.
- **Respeta lo aprobado.** La referencia del usuario y sus decisiones no
  se re-cuestionan (la franja mostaza queda; se puede sugerir su
  ejecución, no su existencia).
- **No edita código ni captura de más.** Solo lee, captura, reporta.
- **El sabor se juzga en captura, no en código.** El código sirve para
  proponer el ajuste concreto; el juicio nace del PNG.
- **Honestidad bidireccional:** si se ve genérico, decirlo con evidencia;
  si se ve bien, decirlo sin relleno.

## Veredicto

`SE VE BIEN / SE VE BIEN CON PULIDO / NECESITA DIRECCIÓN`
+ los hallazgos verbatim + qué está funcionando (2-3 líneas honestas).
