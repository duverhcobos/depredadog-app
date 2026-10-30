# Pendiente: Release Android listo para distribución (firma, permisos, minify)

> **Estado: 🔴 PENDIENTE** — la app compila e instala en release contra el backend local; faltan keystore propio, decisión de minify y build de prod verificado
> **Producto:** frontend
> **Bloqueo:** bloqueante — sin firma release no hay APK/AAB distribuible

## Contexto

Lo ya resuelto (verificado en código):

- `INTERNET` declarado en `src/main/AndroidManifest.xml` ✅ — el release conecta al backend.
- `android:networkSecurityConfig` → `res/xml/network_security_config.xml` ✅ — cleartext http SOLO para `10.0.2.2`/`localhost`/`127.0.0.1` (alias del backend dev local); todo otro dominio exige https. **Si el dev corre en una IP LAN para probar en dispositivo físico, agregar la IP puntual al xml.**
- Release APK dev ya se generó e instaló funcional (firma debug) — verificado login real contra `:3000`.

Pendiente real:

- `build.gradle.kts` usa `signingConfigs.getByName("debug")` — no existe `key.properties` ni keystore `android/app-release.jks` (ambos ya en `.gitignore`).
- `minifyEnabled`/`shrinkResources` sin configurar — decisión pendiente (R8 puede romper `flutter_secure_storage` sin reglas ProGuard).

## Qué falta

- ~~**`INTERNET` en `src/main/AndroidManifest.xml`**~~ ✅ + `usesCleartextTraffic` global NO se activó — se resolvió con `networkSecurityConfig` de dominios puntuales (prod HTTPS intacto, pendiente backend-003).
- **Keystore de release** — `keytool -genkey` → `android/app-release.jks` + `key.properties` + bloque `signingConfigs.release` en `build.gradle.kts` con caída a debug si no existe (convención del skill `release-build`). **Resguardar el keystore** — perderlo = no más updates en Play Store.
- **Minify** — decidir `minifyEnabled`/`shrinkResources`; si se activa, reglas ProGuard para `flutter_secure_storage` y probar login/storage en release.
- **Ofuscación** — `flutter build apk --obfuscate --split-debug-info=<dir>` y guardar los símbolos para leer los crash de Crashlytics (pendiente 001).
- **Build de prod verificado** — `flutter build appbundle --release --dart-define=ENV=prod --dart-define=API_BASE_URL=https://<api-prod>` probado en dispositivo físico.

## Criterio de cierre

- `app-release.aab` firmado con keystore propio, instalable y funcional en dispositivo físico contra el backend de prod.
- `INTERNET` en `src/main/` (✅ ya); cleartext solo en dominios dev puntuales del `networkSecurityConfig` (✅ ya — prod jamás http).
- Símbolos de ofuscación resguardados si se activó.
