# Pendiente: Fallback ciego por statusCode 409 en auth puede etiquetar mal un rechazo

> **Estado: 🔴 PENDIENTE**
> **Producto:** frontend
> **Bloqueo:** condicional — solo muerde cuando `/auth/google` o flujos
> que emiten otros 409 entren a la app (Google OAuth pendiente 006)

## Contexto

Con §028, `auth_repository_impl._mapFailure` mapea primero por `errorCode`
del backend y conserva los fallbacks por statusCode/mensaje detrás. El
fallback `statusCode == 409` → `EmailAlreadyRegisteredFailure` es ciego:
un 409 con `errorCode` **desconocido** cae ahí igual.

El backend (§017) ya emite `GOOGLE_ACCOUNT_ALREADY_LINKED` (409 en
`POST /auth/google` cuando la vinculación pierde una carrera). Si esa ruta
llega a la app sin mapear su código, el usuario vería el copy "este correo
ya tiene cuenta" en vez del real — etiquetado errado, no un crasheo.

Del mismo modo, `ADDRESS_LIMIT_REACHED` (409 en `POST /addresses`) hoy
llega como `CheckoutServerFailure` genérico vía `saveAddress` — aceptable,
pero también podría ganar copy dedicado ("máximo de direcciones alcanzado").

## Qué falta

- Cuando `/auth/google` se integre: mapear `GOOGLE_ACCOUNT_ALREADY_LINKED`
  → failure dedicado con su copy ("Esta cuenta de Google ya está
  vinculada a otro correo").
- Opcional: `ADDRESS_LIMIT_REACHED` → copy dedicado en el checkout/direcciones
  en vez del genérico de infraestructura.
- Revisar entonces si el fallback ciego 409 sigue teniendo sentido o si un
  409 con código desconocido debe caer a `UnknownAuthFailure`.

## Criterio de cierre

- Ningún 409 con `errorCode` conocido por el backend llega a la UI con
  copy de otro motivo.

> Detectado por el `revisor` al auditar §028 (INFO — pre-existente, no
> introducido por el cambio; el fallback 409 ciego existía desde §015).
