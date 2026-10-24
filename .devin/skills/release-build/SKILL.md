---
name: release-build
description: Checklist para generar APK/AAB release de Depredadog — permisos, --dart-define por entorno, mocks de dev, firma y versionado
allowed-tools:
  - read
  - grep
  - glob
triggers:
  - user
  - model
---

Checklist antes de generar un build release de **Depredadog** (`flutter build
apk`/`appbundle`). Lo que en `flutter run` (debug) "funciona" puede romper
en release — el caso típico: el manifest `main/` sin `INTERNET` hace que el
APK falle con "No se pudo conectar al servidor" (el permiso solo existe en
`debug/`/`profile/`).

## Checklist de build

- [ ] **`AndroidManifest.xml` main** tiene `uses-permission INTERNET` —
  los manifests `debug/` y `profile/` NO heredan a release; todo permiso
  que la app use debe estar también en `src/main/`. *(Pendiente en este
  repo: `src/main/` aún no lo declara — agregarlo antes del primer release.)*
- [ ] **`usesCleartextTraffic`** si el backend corre por `http://` (IP LAN
  de desarrollo) — Android bloquea cleartext por defecto en release.
- [ ] **Entorno elegido** vía `--dart-define=ENV=dev|stg|prod`
  (`lib/core/constants/environment/environment.dart`, cuando exista) — sin
  flag cae a `dev`. `API_TOKEN` idem si aplica.
- [ ] **`API_BASE_URL` inyectada** — `environment.dart` no debe tener URLs de
  stg/prod hardcodeadas: pasar `--dart-define=API_BASE_URL=...` (default dev:
  `http://10.0.2.2:3000` para emulador → `pcalientes_backend` local). Sin
  `API_BASE_URL` un build stg/prod apunta al default del emulador y falla en
  device físico.
- [ ] **Versiones sincronizadas**: `version:` de `pubspec.yaml` y
  `Environment.appVersion` (cuando exista) — Dart no lee el pubspec en
  runtime, hay que subir ambas a mano.
- [ ] **Minify/R8**: si se activa `minifyEnabled`/`shrinkResources`,
  verificar plugins sensibles (flutter_secure_storage puede necesitar
  reglas ProGuard).
- [ ] **`flutter analyze` + `flutter test` limpios** antes de buildear.

## Qué es real vs. mock en `dev`

- Todo datasource con mocks de dev queda gateado por
  `Environment.currentEnvironment == EnvType.dev` — `stg`/`prod` siempre
  pegan al backend real (`API_BASE_URL`). Ver skill `environments-secrets`.
- Si se implementa login con Google: `GOOGLE_SERVER_CLIENT_ID` (dart-define)
  con el Web OAuth client ID de Google Cloud — vacío = el botón falla
  visible, no silencioso.

Ojo: el check de conectividad (`networkInfo.isConnected`, cuando exista)
corre antes de cualquier llamada, incluso de los mocks — sin internet el
flujo falla igual con "No se pudo conectar".

## Comandos

```powershell
# Dev — firma debug mientras no exista keystore de release
flutter build apk --release

# Stg
flutter build apk --release --dart-define=ENV=stg --dart-define=API_BASE_URL=https://api.ejemplo.com

# Un APK por arquitectura (más livianos)
flutter build apk --release --split-per-abi

# Play Store: AAB firmado
flutter build appbundle --release --dart-define=ENV=prod
```

Salida: `build/app/outputs/flutter-apk/app-release.apk` (o
`bundle/release/app-release.aab`).

## Firma para distribución real (pendiente de configurar)

Convención del proyecto: keystore real en `android/app-release.jks` +
`android/key.properties` (ambos ya cubiertos por `.gitignore`, NUNCA
commitear); `app/build.gradle.kts` carga `signingConfigs.release` desde
`key.properties` y cae a firma debug si el archivo no existe (CI/dev sin
secretos). La misma key debe firmar toda release/patch futura — cambiarla
invalida updates y la publicación en Play Store.

*Estado actual: el keystore aún no existe y `build.gradle.kts` usa la firma
debug por defecto — configurar antes de la primera distribución fuera de dev.*

## Code push (si se adopta)

Si el proyecto adopta una herramienta de code push (ej. Shorebird), su
configuración (`*.yaml`/`*.json` de defines) se documenta en esta skill en la
misma propuesta que la introduzca. Regla que se conserva: los patches OTA
solo llevan Dart — cambios en plugins nativos, manifests, permisos,
`applicationId`, firma o assets nuevos siempre requieren release nuevo.
