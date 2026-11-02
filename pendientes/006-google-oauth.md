# Pendiente: Login con Google listo para producción (client IDs + SHA-1 release)

> **Estado: 🔴 PENDIENTE** — condicional: el botón de Google existe en la UI pero sin integración; requiere proyecto en Google Cloud
> **Producto:** frontend (requiere config también en backend)
> **Bloqueo:** bloqueante solo si Google login entra al MVP — si se decide lanzar sin él, aceptar y ocultar el botón en prod

## Contexto

El botón "Continuar con Google" (`GoogleSignInButton` compartido) existe en login y en el paso 1 del registro, pero no hay endpoint integrado ni proyecto en Google Cloud. Para que funcione en prod se necesitan client IDs OAuth y la huella del keystore de release — el SHA-1 de debug **no sirve** para la app firmada. Al ser widget compartido, ocultarlo en prod resuelve ambas superficies a la vez.

## Qué falta

- **Proyecto Google Cloud** — OAuth consent screen + client IDs: Android (con **SHA-1 del keystore release** de 003, y el de debug para dev), iOS si aplica, y Web (el backend lo usa para verificar el `idToken`).
- **App** — `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>` en el build (convención del skill `release-build`; declarar en `environment.dart` al integrar).
- **Backend** — `GOOGLE_CLIENT_IDS` de prod en `.env` (pendiente backend-003) incluyendo los client IDs anteriores.
- **SHA-1 por firma** — registrar el fingerprint de debug Y el de release (y el de Play App Signing si Google lo gestiona — revisar "App integrity" en Play Console tras el primer upload).
- **Decisión de alcance** — si Google login no entra al MVP, ocultar el botón en builds de prod hasta integrarlo.

## Criterio de cierre

- Login con Google funcional en build release firmado con el keystore de prod.
- O: botón oculto en prod + decisión documentada de diferir Google login.
