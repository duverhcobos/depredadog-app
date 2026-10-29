# Pendiente: Restaurar sesión al abrir la app

> **Estado: 🟢 RESUELTO** — implementado en propuesta 007-auth-me-session-restore
> **Producto:** frontend
> **Bloqueo:** recomendado (no bloquea el login en sí; si se lanza así, cada
> apertura de la app pide login aunque haya sesión guardada)

## Contexto

Hoy `AuthSession` nace siempre en `false` en cada arranque de proceso — el
splash no revisa si ya hay un `accessToken` guardado en secure storage.
Resultado: cerrar y volver a abrir la app siempre manda a `/login`, aunque
el usuario inició sesión minutos antes.

## Por qué no se resolvió ya

Restaurarla "bien" implica validar el token contra el backend (no solo
comprobar que el archivo existe) — un token guardado puede estar vencido
o revocado (logout desde otro dispositivo). Esa validación es
`GET /auth/me`, que todavía no se integra (es su propio ciclo).

## Qué falta

- Integrar `/auth/me` (propio ciclo, screen-first-workflow).
- En el splash: si hay `accessToken` guardado, llamar a `/auth/me`;
  200 → `AuthSession.markAuthenticated()` + ir a `/home`; 401 → limpiar la
  sesión local y seguir a `/login`.

## Criterio de cierre

- Cerrar y reabrir la app con sesión previa válida lleva a `/home` sin
  pedir login de nuevo.
- Un token vencido/revocado limpia la sesión local y pide login.

## Resolución (propuesta 007)

`GET /auth/me` integrado: `IAuthRemoteDataSource.getMe` →
`AuthRepositoryImpl.restoreSession` (sin token → `NoStoredSessionFailure`
sin tocar red; 401 → `clearSession` + `SessionExpiredFailure`; offline/5xx
→ tokens intactos) → `RestoreSessionUseCase` → `SplashCubit`. El splash
corre el restore en paralelo con la marca mínima de 800 ms y navega a
`/home` (restored) o `/login` (guest). `AuthSession.markAuthenticated(user)`
guarda además el usuario en `currentUser` para las pantallas autenticadas.
