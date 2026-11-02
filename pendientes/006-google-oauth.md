# Pendiente: Login con Google listo para producción (SHA-1 release + publicar consent screen)

> **Estado: � PARCIAL** — flujo Google FUNCIONAL en dev (propuesta 014: SDK → POST /auth/google → sesión, verificado en emulador con clientes OAuth reales); falta la configuración de producción
> **Producto:** frontend (requiere config también en backend)
> **Bloqueo:** bloqueante solo si Google login entra al MVP

## Contexto

El botón "Continuar con Google" (`GoogleSignInButton` compartido) está integrado en login y en el paso 1 del registro (propuesta 014). En dev ya funciona end-to-end con el proyecto Google Cloud real ("Depredadog"): selector de cuentas → consentimiento → `idToken` → POST /auth/google → sesión.

Valores dev configurados (2026-11-02):
- **Web client ID** (serverClientId de la app + `aud` que verifica el backend): `323199681728-75tbhjfu8e9pohi7h3ucmm1smgkpjtsv.apps.googleusercontent.com` — en `.env` backend (`GOOGLE_CLIENT_IDS`) y `--dart-define=GOOGLE_SERVER_CLIENT_ID` en la app.
- **Android client debug**: package `com.depredadog.app` + SHA-1 debug `E9:F0:28:41:17:2C:2F:77:DF:84:A3:67:B7:6B:E2:72:E7:DA:94:50`.
- **Consent screen**: External, modo "Prueba", test user `duverhernandezcobos@gmail.com`.
- El mismo **web client ID sirve para prod** (es el `aud` del idToken) — no hace falta crear otro.

## Qué falta para prod

- **Android client release** — nuevo cliente OAuth Android con el **SHA-1 del keystore release** (pendiente 003: el keystore ni existe aún). El de debug no sirve para la app firmada.
- **SHA-1 de Play App Signing** — si Play gestiona la firma, registrar ese fingerprint también ("App integrity" en Play Console tras el primer upload).
- **Publicar el consent screen** — pasar de "Prueba" a "En producción" (scopes openid/email/profile no exigen verificación) o mantener Prueba gestionando la lista de test users.
- **Backend prod** — `GOOGLE_CLIENT_IDS` del entorno prod con el web client ID (mismo valor dev; sumar el Android client release si se crea).
- **iOS client** — solo si sale build iOS: cliente OAuth iOS + `GIDClientID` en el plist.
- **Decisión de alcance** — si Google login no entra al MVP, ocultar el botón en builds de prod (es widget compartido, resuelve ambas superficies).

## Criterio de cierre

- Login con Google funcional en build release firmado con el keystore de prod.
- O: botón oculto en prod + decisión documentada de diferir Google login.
