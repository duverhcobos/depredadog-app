# Propuesta: Integración de `POST /auth/refresh` — sesión continua tras expirar el access token

Origen: evaluación del módulo auth previa a producción — hallazgo crítico.
El access token vive 15min (`JWT_ACCESS_TTL`) y NADA en la app llama a
`/auth/refresh`: el refresh token de 30 días queda guardado sin usar y el
usuario es expulsado a login cada 15min de inactividad. El `AuthInterceptor`
hoy solo adjunta el Bearer — el propio comentario del archivo lo marca como
pendiente ("se agrega en el ciclo de integración de /auth/refresh").

## Decisiones de diseño

- **El refresh es concern de transporte** (lifecycle del token), no del
  feature auth: se implementa en `core/` sin tocar datasource/repository/
  use cases. Los flujos de dominio no se enteran — el 401 nunca los alcanza.
- **`TokenRefreshService` nuevo en `core/auth/`** — único que conoce el
  endpoint y la persistencia: lee el refresh token, POSTea, guarda los
  tokens nuevos y maneja el fallo definitivo. **Single-flight**: un
  `Future<bool>` en vuelo deduplica 401s concurrentes (varios requests
  disparan a la vez → un solo refresh → todos reintentan).
- **`AuthInterceptor.onError` hace el retry**: 401 y request no marcada →
  `refresh()` → éxito → reintenta la request original con el Bearer nuevo
  (`dio.fetch`); si el retry también 401, el error propaga al caller como
  hoy. Marcador `extra['retried']` = un solo reintento por request — jamás
  loop.
- **La llamada a `/auth/refresh` va por `INetworkService`** (el mismo Dio):
  adjunta el Bearer expirado — inofensivo, el endpoint es `@Public`. El
  interceptor **omite el path `/auth/refresh`** en su onError (la propia
  llamada de refresh no se reintenta a sí misma — anti-recursión).
- **Fallo definitivo (401/403 del refresh)**: borra access+refresh del
  secure storage + `AuthSession.markLoggedOut()` → el guard expulsa a
  /login en la próxima navegación. El 401 de "sesión comprometida" del
  backend (reuso de refresh) cae en la misma vía.
- **Fallo transitorio (sin red, 5xx, timeout)**: NO borra tokens, devuelve
  false — el request original falla y el próximo reintenta el refresh.
- **`restoreSession` se cura gratis**: su `getMe()` → 401 → interceptor
  refresca + reintenta → el usuario entra a /home en vez de login a los
  15min. Cero cambios en el repository.
- **Dio crudo para el retry**: `DioNetworkServiceImpl` expone `Dio get dio`
  documentado "solo para AuthInterceptor"; DI registra el tipo impl + alias
  `INetworkService` para romper el ciclo (interceptor se construye antes
  que el servicio que lo contiene).
- **Limitación aceptada**: `markLoggedOut` no navega por sí mismo (el
  router no tiene refreshListenable) — el guard expulsa en la siguiente
  navegación; suficiente para esta iteración.

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/core/auth/token_refresh_service.dart` | nuevo — single-flight refresh + fallo definitivo (clear + markLoggedOut) |
| `lib/core/network/interceptors/auth_interceptor.dart` | `onError`: 401 → refresh → retry con `extra['retried']`; omite path /auth/refresh |
| `lib/core/network/implementations/dio_network_service_impl.dart` | `Dio get dio` documentado para el interceptor |
| `lib/core/di/setup_di.dart` | `DioNetworkServiceImpl` como singleton tipado + alias `INetworkService`; `TokenRefreshService` lazySingleton; AuthInterceptor con refresher + dioResolver |
| `test/core/auth/token_refresh_service_test.dart` | nuevo — sin refresh token / éxito / 401→clear+logout / 5xx→conserva / dedup single-flight |
| `test/core/network/interceptors/auth_interceptor_test.dart` | extender — 401→retry con token nuevo, flag retried anti-loop, path refresh omitido |

## Contrato backend (ya existe — verificado)

`POST /auth/refresh` público, throttle 10/min, body `{refreshToken}` →
`{accessToken, refreshToken}` (rotación: el refresh devuelto reemplaza al
anterior). Errores: 401 inválido/expirado/comprometido → mismo tratamiento.

## Verificación

1. `flutter analyze` + `flutter test` (suite completa)
2. En vivo: `JWT_ACCESS_TTL=15s` temporal en backend → login → esperar 20s →
   cold restart → splash debe llegar a `/home` sin pedir login (refresh
   transparente). Revertir el TTL después.
