---
name: screen-first-workflow
description: Workflow obligatorio de desarrollo por pantallas en Depredadog — primero la capa de presentación sin conectar (aprobación visual), luego la integración de las demás capas por endpoint (pruebas → aprobación → commit → siguiente endpoint)
triggers:
  - user
  - model
---

# Desarrollo por pantalla — convención del proyecto

El frontend de Depredadog se construye **por pantallas y en dos fases** — nunca
se implementa una feature completa (presentation + domain + data) de una sola
pasada.

## Fase 1 — Presentación (sin conectar)

- Se implementa **solo la capa `presentation/`**: screen, widgets, cubit/bloc
  local con sus estados, textos `.arb`, navegación/ruta.
- **Sin tocar `domain/` ni `data/`**: nada de datasources, repositorios remotos
  ni llamadas reales. Si la pantalla necesita datos para mostrarse, el cubit
  emite estados con datos **mock/estáticos** locales para que el usuario vea
  los estados visuales (loading, error, success, vacío).
- La propuesta de esta fase solo cubre presentation — en una feature nueva la
  estructura `domain/`/`data/` puede quedar solo con los contratos/ports si el
  diseño los exige, pero sin implementación conectada.
- **Gate**: el usuario aprueba lo que ve en el emulador **antes** de pasar a
  integración. No se construye domain/data hasta ese visto bueno.

## Fase 2 — Integración por endpoint

- Se integran `domain/` + `data/` **un endpoint a la vez** — nunca todos juntos:
  1. Integrar el endpoint (datasource → repository impl → use case → conectar cubit).
  2. Probarlo (tests + verificación manual contra el backend real).
  3. El usuario aprueba.
  4. **Commit** (incluye tests + doc del endpoint si aplica).
  5. Recién ahí, siguiente endpoint.

- Si la pantalla tiene varios endpoints asociados (ej. login = `/auth/login` +
  `/auth/google`), cada uno es su propio ciclo de integración.

## Consecuencias en el workflow

- **Propuestas se dividen por fase**: una feature de pantalla genera una
  propuesta de *presentación* y una (o más) propuestas de *integración* —
  numeración propia cada una, enlazadas entre sí.
- Una propuesta de integración puede ser el siguiente número libre aunque otras
  pantallas de presentación ya se aprobaron en medio.
- El ciclo de subagentes no cambia: propuesta → implementador → revisor →
  usuario — solo que cada ciclo es más pequeño (una fase o un endpoint).
- Los pendientes/workarounds que deje una fase (ej. botón sin endpoint real) se
  marcan `// PROVISIONAL` y si bloquean producción van a `pendientes/`
  (ver `pendientes-produccion`).

## Ejemplo canónico — auth

```
propuesta NNN: LoginScreen (presentation)   → usuario aprueba visual
propuesta NNN: integración /auth/login      → probar → aprueba → commit
propuesta NNN: integración /auth/google     → probar → aprueba → commit
propuesta NNN: RegisterScreen (presentation) → aprueba visual
propuesta NNN: integración /auth/register   → probar → aprueba → commit
...
```
