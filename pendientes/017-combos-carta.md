# Pendiente: Combos en la app — carta de combos ya decidida

> **Estado: 🔴 PENDIENTE** — decisiones de negocio tomadas con el
> dueño 2026-11-20; implementación aplazada ("después, cuando la
> app esté completa").
> **Producto:** app + backend
> **Bloqueo:** post-MVP — los combos hoy solo viven en la carta física.

## Contexto

El dueño diseñó su carta de combos (margen base 40% en comida;
bebidas fuera porque se revenden). Las bebidas NO entran en combos.
Estructura aprobada:

| Combo | Contenido | Precio | Ganancia | Margen |
|-------|-----------|--------|----------|--------|
| Combo Cachorro | Cachorro + papas | $17.000 | $5.600 | 33% |
| **La Regla** | 2 o 3 perros a elección + papas GRATIS | desde $28.000 | $8.2k–18.6k | 29–34% |
| Dúo Alfa | 2× Depredador + papas gratis | $36.000 | $11.400 | 32% |
| Manada −15% (promo lanzamiento) | 4+ perros a elección −15% | ~$47.5k–61k | $14k–18k | 29% |

- Las bebidas se venden por separado — el counter hace upsell
  "agrega la gaseosa por $3.000".
- "La Regla" cubre dúo y trío en una mecánica; el Manada es la
  única con % y va enmarcada como promo de lanzamiento (salida
  limpia para ajustar/quitar).
- Redondeo de cobro a $500 hacia abajo en el −15%.

## Qué falta para implementarlo en la app

- **Modelo de combo**: `combo_items` existe en el schema pero no
  está cableado al catálogo ni a órdenes — propuesta backend:
  response de catálogo con combos (componentes + regla), pricing
  del lado del servidor (nunca confiar en el total del cliente),
  y cómo se guardan las líneas del pedido (¿combo como ítem único
  o desagregado en componentes para cocina?).
- **Regla de papas gratis / % por cantidad**: no es un producto —
  es lógica de precio por N ítems elegibles. Decidir si el
  backend la calcula o si se modela como combo flexible con
  selector (probablemente mejor: la app arma el pedido, el
  servidor valida el descuento).
- **Categoría "Combos"** en el catálogo (`cat_combos.png` ya es
  el cover) + detalle con selector de perros para los flexibles.
- **Comanda de cocina**: la card §043 debe desglosar el combo en
  sus componentes con las personalizaciones de cada perro.
- **Cierre de caja**: el resumen del día debe contar combos bien
  (revisar que ingresos y unidades cuadren).

## Criterio de cierre

- El cliente puede pedir los 4 combos desde la app con precios
  validados por el servidor; cocina recibe el desglose por ítem;
  el cierre cuadra.
