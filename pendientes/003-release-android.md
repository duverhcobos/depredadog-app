# Pendiente: Release Android listo para distribución (firma, permisos, minify)

> **Estado: 🔴 PENDIENTE** — la app solo corre en debug; faltan keystore, permiso INTERNET en `src/main/` y decisión de minify
> **Producto:** frontend
> **Bloqueo:** bloqueante — sin firma release no hay APK/AAB distribuible; sin `INTERNET` en `src/main/` el release no conecta al backend

## Contexto

El skill `release-build` lista lo que falta (verificado en código):

- `android/app/src/main/AndroidManifest.xml` **no declara** `uses-permission INTERNET` — los manifests `debug/`/`profile/` no heredan a release → el APK release compila pero falla con "sin conexión".
- `build.gradle.kts` usa `signingConfigs.getByName("debug")` — no existe `key.properties` ni keystore `android/app-release.jks` (ambos ya en `.gitignore`).
- `minifyEnabled`/`shrinkResources` sin configurar — decisión pendiente (R8 puede romper `flutter_secure_storage` sin reglas ProGuard).

## Qué falta

- **`INTERNET` en `src/main/AndroidManifest.xml`** + `usesCleartextTraffic` NO debe activarse si el API de prod es HTTPS (pendiente backend-003).
- **Keystore de release** — `keytool -genkey` → `android/app-release.jks` + `key.properties` + bloque `signingConfigs.release` en `build.gradle.kts` con caída a debug si no existe (convención del skill `release-build`). **Resguardar el keystore** — perderlo = no más updates en Play Store.
- **Minify** — decidir `minifyEnabled`/`shrinkResources`; si se activa, reglas ProGuard para `flutter_secure_storage` y probar login/storage en release.
- **Ofuscación** — `flutter build apk --obfuscate --split-debug-info=<dir>` y guardar los símbolos para leer los crash de Crashlytics (pendiente 001).
- **Build de prod verificado** — `flutter build appbundle --release --dart-define=ENV=prod --dart-define=API_BASE_URL=https://<api-prod>` probado en dispositivo físico.

## Criterio de cierre

- `app-release.aab` firmado con keystore propio, instalable y funcional en dispositivo físico contra el backend de prod.
- `INTERNET` en `src/main/`; cleartext off.
- Símbolos de ofuscación resguardados si se activó.
