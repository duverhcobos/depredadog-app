# Pendiente: "Gratis" en el copy del carrusel de promos

> **Estado: 🔴 PENDIENTE** — detectado en evaluacion-modulo de catalog
> **Producto:** app
> **Bloqueo:** menor — copy de marketing en datos de presentación mock

## Contexto

El usuario pidió eliminar la palabra "gratis" de toda la UI (se quitó
del picker de reemplazo, la fila elegida y los tags de Toppings/Salsas;
la key `detailFreeTag` fue retirada del l10n). Queda **una** ocurrencia:
la promo mock del carrusel del home dice "Envío gratis desde $20.000".

No se tocó porque es copy de marketing dentro de una frase (no el tag
suelto que el usuario vio y rechazó) y porque las promos aún son datos
de presentación sin backend — el copy real llegará con el módulo de
promociones.

## Qué falta

- Confirmar con el usuario si "envío gratis" como concepto tampoco le
  gusta, o solo el tag "Gratis" suelto.
- Si lo quiere fuera: reemplazar el copy del slide mock (o esperar al
  módulo promotions y sembrar el copy real directamente).

## Criterio de cierre

- Ninguna cadena visible con "gratis" salvo confirmación explícita del
  usuario de que esa frase sí aplica.
