# Propuesta 044 — Firma release propia para distribución

> **Estado: APROBADA** — el usuario pidió la compilación release dentro del despliegue completo (Supabase + Render + release) en sesión; esta propuesta documenta el cambio.
> **Producto:** frontend
> **Pendiente que cierra:** app/003 (parcial — falta el build de prod verificado contra la API pública, decisión de minify y símbolos de ofuscación).

## Contexto

`build.gradle.kts` firmaba release con la key **debug** — no había `app-release.jks` ni `key.properties`. Sin keystore propio no hay APK/AAB distribuible ni actualizable.

## Cambios

1. **`android/app-release.jks`** generado con `keytool -genkeypair -keyalg RSA -keysize 2048 -validity 10950 -alias depredadog` — CN=Depredadog, 30 años de vigencia. Gitignored (`**/*.jks` ya cubierto).
2. **`android/key.properties`** con `storePassword`/`keyPassword`/`keyAlias`/`storeFile` — gitignored. **Nota:** PKCS12 (formato default del keytool moderno) no admite key password ≠ store password — ambas iguales.
3. **`android/app/build.gradle.kts`** — carga `key.properties` en `Properties`, crea `signingConfigs.release` SOLO si el archivo existe, y `buildTypes.release` firma con release o cae a debug (CI/dev sin secretos sigue compilando).

## Verificación

- `flutter build apk --release` → `app-release.apk` firmada con `CN=Depredadog` (verificado con `apksigner verify --print-certs`).
- La misma key firmará TODA release/patch futura — **resguardar `app-release.jks` fuera del repo** (perderla = no más updates en Play Store).

## Fuera de alcance

- `minifyEnabled`/`shrinkResources`/`--obfuscate` — decisión pendiente (reglas ProGuard para `flutter_secure_storage` + guardar símbolos para Crashlytics).
- `API_BASE_URL` de prod — se pasa al build final con `--dart-define` una vez exista el servicio en Render.
