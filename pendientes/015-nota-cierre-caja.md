# Pendiente: Campo nota opcional en el cierre de caja

> **Estado: 🔴 PENDIENTE** — detectado en evaluacion-modulo de admin/Cocina
> **Producto:** app
> **Bloqueo:** menor — el cierre funciona perfecto sin nota; el
> campo quedó diferido por decisión del dueño en la encuesta §041.

## Contexto

`POST /admin/day-close` acepta `{ "note": "..." }` (maxLength 500)
y la guarda en el registro `day_closes` — útil para anotar
contexto ("cierre lento por la lluvia", "cerré temprano"). La app
manda el POST sin body (`postDayClose()` en el datasource) porque
la pantalla no tiene el input.

## Qué falta

- `postDayClose({String? note})` + parámetro por la cadena
  repo → use case → cubit (`closeDay({String? note})`).
- TextField opcional en `admin_day_close_screen.dart` (decisión de
  diseño: ¿siempre visible? ¿expandible?), con el contador de 500
  caracteres.
- El resumen de éxito podría mostrar la nota si vuelve en el
  snapshot (el POST la devuelve en `note`).

## Criterio de cierre

- La nota viaja y se persiste (verificable en `day_closes.note`);
  omitida, el cierre sigue funcionando igual que hoy.
