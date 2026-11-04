# Pendiente: Catálogo real de toppings y salsas (datos de negocio)

> **Estado: 🔴 PENDIENTE** — el usuario aún no tiene la lista real; las
> actuales en la app son datos mock inventados
> **Producto:** ambos
> **Bloqueo:** bloqueante — antes de lanzar el catálogo debe reflejar el
> menú real del negocio

## Contexto

La pantalla de detalle de producto (§018) muestra secciones de **Toppings**
y **Salsas** alimentadas por `toppingCatalog` y `sauceCatalog` en
`lib/features/home/presentation/data/catalog_mock.dart`. Esos nombres
(Papa ripio, Queso rallado, Cebolla crispy, Tocineta picada, Jalapeños /
Ketchup, Mayonesa, Mostaza, Salsa de piña, Salsa rosada, Salsa tártara,
BBQ) **fueron inventados como mock de presentación** — el usuario nunca
entregó el catálogo real.

Las **reglas de negocio sí están confirmadas**: toppings y salsas gratis,
ilimitados, sí/no; ingredientes propios quitables; ingrediente de otro
perro = adicional pago; pan + salchicha no quitables.

## Qué falta (datos que debe confirmar el dueño)

- Lista real de **toppings** (nombres tal como se venden).
- Lista real de **salsas**.
- "Las salsas de la casa" (tagline de Manada de Papas): ¿son las mismas
  del catálogo global o hay salsas exclusivas por producto?
- Ambigüedad cheddar: "salsa de queso cheddar" está como **ingrediente**
  adicional pago — confirmar si también es salsa gratis seleccionable.
- Alcance: ¿toppings/salsas son una sola lista global para todo el menú,
  o algunos aplican solo a perros / solo a papas?

## Criterio de cierre

- `toppingCatalog`/`sauceCatalog` (y el seed del backend) contienen las
  listas reales confirmadas por el dueño.
- Resueltas las ambigüedades de "salsas de la casa", cheddar y alcance
  por categoría.
