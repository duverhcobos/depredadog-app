# Pendiente: Historial definitivo de Cocina (ubicación, paginación, listado de cierres)

> **Estado: 🔴 PENDIENTE** — detectado en evaluacion-modulo de admin/Cocina
> **Producto:** app
> **Bloqueo:** recomendado — el historial provisional funciona pero
> solo muestra la página 1 (los ~20 más recientes) y su ubicación
> es la del atajo 🕐 del header, no la definitiva.

## Contexto

`admin_history_screen.dart` es la pantalla provisional del §036:
lista plana de `state.history` (done cerrados + cancelados) con
cards en solo-lectura que sí navegan al detalle. El cubit solo
pide la página 1 del bucket `history` (`kAdminHistoryPageSize=20`,
`load()` en `admin_queue_cubit.dart`) — no hay load-more ni
paginación. La ubicación definitiva ("historial lo resolvemos
después dónde va", dueño) quedó diferida al roadmap junto a Caja:
¿tab propio? ¿dentro de una sección Caja con los cierres?

## Qué falta

- Decidir ubicación y diseño definitivos con el dueño.
- Paginación real (scroll infinito o pager) sobre el bucket
  `history` del backend — el repo ya soporta `page`.
- Considerar dentro del mismo rediseño: listado de cierres de caja
  cuando exista `GET /admin/day-closes` (pendiente backend 014) —
  agrupar el historial por cierre respondería "¿qué se vendió el
  martes?" mejor que una lista plana.

## Criterio de cierre

- Ubicación decidida + diseño aprobado por el dueño (gate visual).
- El historial completo se navega (todas las páginas), con detalle
  read-only por pedido como hoy.
