---
name: evaluacion-modulo
description: Gate obligatorio al cerrar un módulo de la app — evaluación 10/10 de producción con rúbrica por lado, gaps clasificados por severidad, críticos resueltos en el momento y el resto a pendientes/
allowed-tools:
  - read
  - grep
  - glob
  - exec
  - run_subagent
triggers:
  - user
  - model
---

## Cuándo corre

**Gate obligatorio al cerrar un módulo** (auth, catalog, orders, ...):
antes de declarar el módulo terminado y pasar al siguiente, correr esta
evaluación. También cuando el usuario pida "evalúa el módulo X" en cualquier
momento.

## Qué produce

1. **Score /10 por lado** (frontend y backend por separado — el backend
   evalúa el suyo con su propia skill; aquí se califica el frontend).
2. **Tabla de gaps** con severidad `[CRITICO / IMPORTANTE / MENOR]` y
   evidencia `archivo:línea` — nunca una opinión sin citar el código.
3. **CRÍTICO → se resuelve en el momento** (propuesta + implementación +
   verificación, screen-first-workflow). **IMPORTANTE/MENOR → pendiente**
   documentado en `pendientes/` con el formato del skill pendientes-produccion.

## Rúbrica frontend (qué revisa un 10/10)

**Seguridad**
- Ningún token, contraseña, idToken ni dato sensible llega a logs — ni siquiera
  en dev (LogInterceptor con flags de contenido en false).
- Tokens en secure storage con borrado selectivo (`deleteKeys`, jamás
  `deleteAll`); lifecycle completo funciona: login → expiración → refresh
  transparente → expulsión limpia.
- Autofill/teclados no guardan credenciales no enviadas; nada sensible en
  `extra` de navegación ni en la pantalla.

**Funcionalidad**
- Todo endpoint del módulo está integrado de verdad contra el backend real —
  no mock — y **verificado en vivo en el emulador** (los 3 escenarios:
  éxito, error del server, cancelación/timeout).
- Cada failure mapeado a copy de UI (`Either` — nada crudo llega al cubit);
  estados loading/error/empty/success cubiertos.

**Arquitectura**
- Interfaces en cada frontera (datasource/gateway/storage/network); el SDK de
  terceros solo vive en el gateway; `core` no importa `features`; los cubits
  no conocen HTTP.
- Convenciones: `solid-clean-architecture`, `bloc-patterns`,
  `file-size-refactoring`, `navigation-routing`.

**UX/i18n**
- Todo texto visible por `AppLocalizations` (sin literales) — `i18n-workflow`.
- Toasts/feedback efímero por `AppToast`; design-system.yaml + changelog al
  día tras cambios visuales (design-system-docs).

**Pruebas**
- Tests por camino: éxito + cada failure + bordes (concurrencia, reintentos,
  storage fallando). `flutter analyze` limpio + `flutter test` verde.

## Clasificación de severidad

- **CRITICO**: rompe el flujo de un usuario real, filtra secretos, o deja al
  usuario atrapado/expulsado incorrectamente en producción.
- **IMPORTANTE**: degrada seguridad/UX o deja un caso borde real sin cubrir,
  pero existe workaround.
- **MENOR**: polish, convención menor, mejora de mantenibilidad.

## Formato del reporte

```
## Frontend — X/10
Lo que ya está: <tabla área → evidencia>
Lo que falta para el 10:
- CRITICO: <gap> (<archivo:línea>) → se resuelve ahora
- IMPORTANTE/MENOR: <gap> → pendientes/NNN
```

Tras resolver los críticos, reportar score final y pendientes creados.
