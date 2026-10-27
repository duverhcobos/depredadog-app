# Pendiente: Crashlytics / logger de producción en la app

> **Estado: 🔴 PENDIENTE** — sin logger de producción; `debugPrint` es no-op en release
> **Producto:** frontend
> **Bloqueo:** bloqueante (observabilidad)
> **Origen:** propuesta 001-app-bootstrap (app) — antes `pendientes/003` en el repo backend, movido al crear la carpeta propia de la app

## Contexto

`setup_di.dart` registra `DebugLoggerServiceImpl` para `ILoggerService` en
todos los entornos — marcado `// PROVISIONAL`. En release `debugPrint` es
no-op, así que un crash en prod no deja rastro.

## Qué falta

- Integrar Firebase Crashlytics (`firebase_core` + `firebase_crashlytics`) y
  crear `CrashlyticsLoggerServiceImpl`; resolver impl por
  `bool.fromEnvironment('dart.vm.product')` como prevé la skill `solid-clean-architecture`.
- Decisión previa: proyecto Firebase de Depredadog + `google-services.json`/
  `GoogleService-Info.plist` (secretos — no commitear).

## Alternativa evaluable

Sentry (`sentry_flutter`) si no se quiere Firebase — misma idea: el impl se
swapea en `setup_di` sin tocar consumers (el puerto ya está).
