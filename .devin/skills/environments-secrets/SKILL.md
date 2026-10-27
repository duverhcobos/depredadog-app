---
name: environments-secrets
description: Manejo de entornos (dev/stg/prod), variables --dart-define y secretos en Depredadog
triggers:
  - user
  - model
---

Reglas para manejar entornos y secretos en **Depredadog**, un proyecto camino a producción.

## Entornos

- **Nunca hardcodear URLs, tokens o API keys** en el código fuente.
- Toda variable de entorno se define exclusivamente vía `--dart-define` y se centraliza en
  `lib/core/constants/environment/environment.dart` (`Environment`). Ningún otro archivo debe leer
  variables de entorno directamente.
- Para agregar una nueva variable: editar `environment.dart` usando
  `String.fromEnvironment`.
- Comandos por entorno:
  ```bash
  # dev — emulador Android (API_BASE_URL default = localhost del host vía 10.0.2.2)
  flutter run --dart-define=ENV=dev
  # dev — dispositivo físico en la misma LAN (backend bindea 0.0.0.0; revisar firewall de Windows)
  flutter run --dart-define=ENV=dev --dart-define=API_BASE_URL=http://<ip-lan-del-pc>:3000
  # staging
  flutter run --dart-define=ENV=stg --dart-define=API_BASE_URL=<url-api-stg>
  # producción
  flutter build appbundle --dart-define=ENV=prod --dart-define=API_BASE_URL=<url-api-prod>
  ```
  Variables activas hoy: `ENV` (`dev`/`stg`/`prod`, default `dev`) y
  `API_BASE_URL` (default `http://10.0.2.2:3000` = localhost del host vía emulador).
  Toda variable nueva se declara primero en `environment.dart` — no inyectar
  `--dart-define` de variables que `environment.dart` no lea (se ignoran
  silenciosamente).
- Nunca usar archivos `.env` de texto plano: viajan en claro dentro del APK/IPA y son el
  archivo que más se filtra a git por descuido. El mecanismo `--dart-define` compila los
  valores en el binario — ojo, igual son **extraíbles** con ingeniería inversa: solo
  valores no sensibles (URLs, client IDs, keys públicas acotadas). La autorización fuerte
  la da el JWT desde secure storage, nada más vive en el cliente.

## Reglas de seguridad reforzadas (proyecto camino a producción)

- **Cero endpoints/datos de prueba fuera de `dev`:** `dummyjson.com` u otros mocks públicos solo
  pueden usarse cuando `Environment.currentEnvironment == EnvType.dev`. Los entornos `stg` y `prod`
  deben apuntar siempre a infraestructura real de Depredadog; nunca dejar un `TODO`/URL
  placeholder sin avisar explícitamente al usuario. Cualquier lógica "truco" específica de una API
  de pruebas (ej. transformar email en username) debe estar gateada por entorno, nunca ejecutarse
  incondicionalmente.
- **Manejo de secretos reforzado:** nunca imprimir, loguear ni comitear tokens, API keys o
  credenciales reales — ni siquiera en ejemplos dentro de `.md`, ni en logs de
  debug. Si se necesita confirmar que un token fue inyectado, loguear solo si está presente/vacío,
  nunca el valor. Si se encuentra un secreto real en el repo, avisar al usuario en vez de
  simplemente borrarlo o versionarlo.
- **TLS/certificados:** cualquier bypass de validación de certificados (ej. certificados
  autofirmados en desarrollo local) debe:
  1. Estar condicionado explícitamente a `Environment.currentEnvironment == EnvType.dev` (nunca
     activo en `stg`/`prod`).
  2. Usar matching exacto de IP/host (regex de octetos completos), nunca `String.contains(...)`
     por substring, para evitar bypasses accidentales en hosts que contengan esos caracteres.
- **Cambios en flujos de sesión/token:** cambios en el guard de rutas, interceptores de
  auth/refresh token, el datasource de sesión segura o cualquier cosa relacionada con
  sesión/tokens deben explicarse claramente al usuario antes o al momento de aplicarlos, dado su
  impacto en seguridad.
- **Sin atajos "provisionales" silenciosos:** si por falta de información hay que dejar un valor o
  contrato temporal (URL, key, texto, forma de un endpoint todavía no confirmado por backend),
  declararlo explícitamente en la respuesta al usuario y marcarlo en el código con un comentario
  visible (ej. `// PROVISIONAL: ...`); no dejarlo implícito como si fuera definitivo.
- **Almacenamiento local seguro:** al usar `flutter_secure_storage`, evitar `deleteAll()` salvo que
  sea intencional; borrar solo las claves relevantes a la operación (ej. logout borra solo claves
  de auth, no todo el storage compartido con otras features).
