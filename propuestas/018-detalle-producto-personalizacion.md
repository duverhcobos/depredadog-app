# Propuesta: Detalle de producto + personalización (presentación)

Pantalla donde se configura un perro antes del carrito — el corazón del
producto ("armá tu presa"). **Fase presentación** (screen-first): datos
del mock extendido, "Agregar al carrito" → toast provisional.

## Modelo de dominio decidido por el usuario

```
PERRO = pan + salchicha          FIJOS — los únicos no quitables
      + ingredientes propios     quitables (sin descuento)
      + adicionales              ingredientes de OTROS perros, c/u con su precio
      + toppings                 gratis, ilimitados, sí/no
      + salsas                   gratis, ilimitadas, sí/no

Precio final = base + Σ adicionales      (sin cantidades — agregar o no)
```

- Los ingredientes son un **catálogo global**; cada perro referencia los
  que trae por defecto y el resto se ofrece como adicional.
- `CatalogItem.ingredientIds` (estructura) reemplaza al string
  `ingredients` como fuente de la composición.
- **UI**: pantalla de detalle propia (decisión: no bottom sheet — ~20
  opciones no caben). Tanto el tap en la card como el "+" abren esta
  pantalla (recomendación aceptada: todo es personalizable, el "+" sin
  opciones escondería la feature).

## Pantalla (diseño final — tras iteración del usuario)

La primera versión (filas planas sobre negro + hero de franja parcial)
fue rechazada: "muy simple, nada parecido a los estilos trabajados".
El diseño aprobado usa la gramática completa de §017:

- **Firma**: SignatureStrip full-height detrás de todo (Stack).
- **Título**: nombre del producto Anton mostaza "naciendo" de la
  franja (mismo motivo `widthFactor 0.602` del título de categoría) —
  **dentro del scroll** como primer ítem del ListView (decisión del
  usuario: "los títulos entren en el scroll, la flecha atrás no" —
  aplica también a category_products, cuyo header se movió igual).
- **Flecha back**: oscura (onPrimary), `Positioned` fija sobre la
  franja — único elemento que no scrollea.
- **Card del producto**: straddle_card 150dp `surfaceContainerHigh`
  con la imagen flotante a escala hero + composición (bodySmall) +
  precio base primary.
- **Secciones** (cards straddle, `CustomizationSection`): ¿Se le
  quita algo? (RemovableRow incluido→check→tachado; pan y salchicha
  no aparecen — sin nota explicativa, "se sabe, sino no sería un
  perro") · ¿Le agregamos algo más? (OptionRow `+$X.XXX`) · Toppings
  (tag "Gratis" + SelectChips) · Salsas (idem).
- **Footer fijo**: fondo opaco surface + hairline (la franja no se
  filtra debajo — el "Total" crema y el botón mostaza se camuflaban):
  Total dinámico (base + Σ adicionales) + FilledButton "Agregar al
  carrito" → toast provisional.

## Archivos

| Archivo | Acción |
|---------|--------|
| `catalog_mock.dart` | +`Ingredient`(id,name,additionalPrice), `ingredientCatalog`, `toppingCatalog`, `sauceCatalog`, `CatalogItem.ingredientIds`, `adicionalesFor()`, `catalogItemById()` |
| `screens/product_detail_screen.dart` | nueva — stateful con 4 sets de selección + total |
| `widgets/customization_section.dart` | nueva — `_Section` + rows compartidos |
| `app_router.dart` | hija `product/:productId` bajo `category/:categoryId` |
| `product_card.dart` / `hero_product_card.dart` | tap y "+" → push al detalle |
| `app_es.arb` | +8 claves → gen-l10n |
| `test/.../product_detail_screen_test.dart` | render, toggle adicional actualiza total, quitar tacha, CTA |
