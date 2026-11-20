# Pendiente: Login con Google listo para producción

> **Estado: ✅ FUNCIONAL en prod para el dueño** — login Google verificado en APK release firmada contra Render (2026-11-20)
> **Producto:** frontend (requiere config también en backend)

## Contexto

El botón "Continuar con Google" (`GoogleSignInButton` compartido) está integrado en login y en el paso 1 del registro (propuesta 014). SDK → `idToken` → POST /auth/google → sesión.

**Proyecto OAuth de producción** (2026-11-20): creado desde cero en el correo nuevo del dueño — el proyecto viejo quedó en otra cuenta y se abandonó. Valores:

- **Web client ID** (`serverClientId` de la app + `aud` que verifica el backend): `924464796986-hn07t8pmbosktloo8k4erhohm9v47nct.apps.googleusercontent.com` — en `.env` backend, `render.yaml` (`GOOGLE_CLIENT_IDS`) y `--dart-define=GOOGLE_SERVER_CLIENT_ID` en la app.
- **Android client release**: package `com.depredadog.app` + SHA-1 keystore release `79:95:FA:A5:CD:B0:CF:C0:8F:C3:97:1A:C9:DA:7B:5F:67:E3:D3:FF`.
- **Consent screen**: External, modo "Prueba" — test user `duverhernandezcobos@gmail.com` (el admin sembrado; entró directo como dueño en el primer login — `google-login.use-case` vincula `googleId` sin tocar `role`).

## Qué falta

- **Publicar el consent screen** — hoy SOLO entran los correos en "Test users". Para clientes finales hay que pasar de "Prueba" a "En producción" (scopes openid/email/profile no exigen verificación de Google) o agregar cada correo como test user mientras tanto.
- **SHA-1 de Play App Signing** — solo si se publica en Play Store y Play gestiona la firma: registrar ese fingerprint adicional ("App integrity" en Play Console tras el primer upload).
- **iOS client** — solo si sale build iOS: cliente OAuth iOS + `GIDClientID` en el plist.

## Criterio de cierre

- ~~Login con Google funcional en build release firmado con el keystore de prod.~~ ✅ hecho
- Consent screen publicada (o lista de test users gestionada) para que cualquier cliente pueda entrar.
