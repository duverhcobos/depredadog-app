# Propuesta: Carrito — panel de detalle por secciones + chip "Detalle" (§021b)

Revisión visual del usuario sobre el panel implementado en §021: no le gusta la
organización "Lleva: / Sin: / Extras:" en líneas corridas. Pide que el detalle se
organice por las **secciones de la pantalla de personalización** (ingredientes,
adicionales, toppings, salsas), cada ítem listado con **punto mostaza**; que se
quite el texto-resumen debajo del título; y que el chevron suba al nivel del
título junto a un **chip "Detalle"**.

Decisiones del usuario (encuesta):

- Los quitados van en **sección aparte "Se le quitó"** (no tachados dentro de
  Ingredientes).
- Los títulos de sección usan el **tratamiento mostaza estilo Anton** (misma
  familia que "¿Se le quita algo?" del detalle, un paso más pequeño).

## Cambios

### Modelo

- `CartModifier.group` (nuevo campo, nullable → enum
  `CartModifierGroup { ingredient, extra, topping, sauce }`): de qué grupo de
  personalización vino la fila — snapshot como `optionName`/`priceDelta`,
  porque el panel no puede resolver el producto (puede ya no estar en la
  carta). Lo llena `_buildModifiers` del detalle según el set de origen
  (removed/replacements → ingredient, extras → extra, toppings → topping,
  sauces → sauce). Nullable: fixtures de test y filas sin etiquetar caen como
  `added` a Adicionales (fallback razonable). NO entra a `sameConfiguration`
  (misma opción nunca está en dos grupos — la clave `optionId:action:priceDelta`
  ya lo discrimina).

### Tile colapsado (cart_item_tile.dart)

- Se elimina la línea de resumen de modificadores (muere
  `cart_item_summary.dart` — `modifierTokens` queda sin uso).
- Fila de título: `Expanded(nombre Anton)` + **chip "Detalle"** — píldora
  outlined (borde outlineVariant, label w600, chevron `expand_more/less`
  dentro) — es el único control del desplegable (Semantics expanded + label
  `cartItemDetailToggle`; hit ≥ 40dp).
- `unitPrice` cuando `quantity > 1` pasa a línea propia bajo el título
  (bodySmall atenuado) — el slot derecho ahora es del chip.

### Panel (cart_item_detail_panel.dart)

Secciones con título Anton mostaza pequeño + ítems con bullet `•` primary
(fila: punto 6px + texto con sangría francesa), solo las que aplican:

- **Ingredientes** — `includedNames` del snapshot.
- **Se le quitó** — filas `removed`; reemplazo gratis como
  `agotado → reemplazo` (vínculo vía `replacesOptionId`, la fila `added` del
  reemplazo no se repite en Adicionales).
- **Adicionales** — `added` group `extra` (o sin grupo) con `+$X.XXX` mostaza.
- **Toppings** — `added` group `topping`.
- **Salsas** — `added` group `sauce`.
- Ítem sin snapshot ni modifiers → fallback "Tal cual de la carta".
- Botón "Editar" se conserva igual.

### l10n

- `cartDetailIncluded` "Lleva:" → se retira (reemplazada por secciones).
- `cartDetailRemoved` → "Se le quitó" (cambia el valor).
- `cartDetailExtras` → "Adicionales" (cambia el valor).
- Nuevas: `cartDetailIngredients` "Ingredientes", `cartDetailToppings`
  "Toppings", `cartDetailSauces` "Salsas", `cartItemDetail` "Detalle" (chip).

### Tests

- `cart_item_summary_test.dart` → se elimina con su archivo.
- `cart_item_detail_panel_test.dart` → reescrito: secciones, bullets, vínculo
  del reemplazo, precio mostaza, fallback.
- `cart_screen_test.dart` → el tap va al chip "Detalle"; aserciones por
  sección; "Tal cual" ahora solo aparece dentro del panel expandido.
- Fixtures con `CartModifier` sin `group` siguen compilando (nullable).

### Design system

`design-system.yaml` → spec de `cart` reescrito (tile + panel) → 1.23.0.
