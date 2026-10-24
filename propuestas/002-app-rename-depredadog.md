# Propuesta: Renombrar la app a **Depredadog**

Rebrand del producto: `PCalientes` → **Depredadog** (app de perros calientes).
Decisión del usuario — aplica sobre el bootstrap recién implementado
(001-app-bootstrap), antes de su validación visual y commit.

## Alcance aprobado

- **App: renombre completo** — nombre visible, package `depredadog_app`,
  `applicationId`/`namespace` `com.depredadog.app`, carpeta del repo
  `depredadog_app` (la renombra el usuario con el IDE cerrado), imports.
- **Backend: solo docs/etiquetas** — la carpeta `pcalientes_backend`,
  `package.json` y las BDs `pcalientes_db`/`pcalientes_db_test` quedan como
  código interno.
- **Marca**: icono flama **provisional** (el usuario tiene logo propio en
  camino). Paleta condimentos sin cambios. Tagline nuevo de hot-dogs.
- **Agentes/skills**: referencias de producto `PCalientes` → `Depredadog`;
  rutas `pcalientes_app` → `depredadog_app`; `pcalientes_backend` intacto.

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `pubspec.yaml` | `name: depredadog_app`, description |
| `lib/app.dart` | `title: 'Depredadog'` |
| `lib/l10n/app_es.arb` | `appName`, `welcomeTitle`, `splashTagline` + `gen-l10n` |
| `test/**/*.dart` | imports `package:pcalientes_app/` → `package:depredadog_app/` + texto del welcome test |
| `android/app/build.gradle.kts` | `namespace` + `applicationId` → `com.depredadog.app` |
| `android/.../MainActivity.kt` | `package com.depredadog.app` + mover a `kotlin/com/depredadog/app/` |
| `android/app/src/main/AndroidManifest.xml` | `android:label="Depredadog"` |
| `ios/Runner/Info.plist` | CFBundleName + CFBundleDisplayName → `Depredadog` |
| `ios/Runner.xcodeproj/project.pbxproj` | `PRODUCT_BUNDLE_IDENTIFIER` → `com.depredadog.app` (+RunnerTests) |
| `Design/design-system.yaml` | `product: Depredadog` |
| `template_flutter.iml` | Eliminar (IDE lo regenera) |
| `AGENTS.md`, `README.md`, `ENVIRONMENTS.md`, `I18N_GUIDE.md`, `promt_solid.md`, `.devin/**`, `propuestas/*.md` | Texto `PCalientes` → `Depredadog`; `pcalientes_app` → `depredadog_app` |
| `../pcalientes_backend/**/*.md` | Solo docs: `PCalientes` → `Depredadog` (rutas/package/BDs intactos) |
| `../pcalientes_backend/pendientes/003-crashlytics-app.md` | Mismo tratamiento de nombre de producto |

## Valores destino

- `appName`: `"Depredadog"`
- `welcomeTitle`: `"Bienvenido a Depredadog"`
- `splashTagline`: `"Perros calientes que muerden de vuelta"`
- `title` de MaterialApp: `Depredadog`
- package: `depredadog_app`
- applicationId/namespace: `com.depredadog.app`
- Bundle ID iOS: `com.depredadog.app` (+ `com.depredadog.app.RunnerTests`)

## Orden de aplicación

1. `pubspec.yaml` → `flutter pub get`
2. Reemplazo de imports en `test/` y textos en `lib/` + `app_es.arb` → `flutter gen-l10n`
3. Android: gradle + manifest + mover `MainActivity.kt`
4. iOS: Info.plist + pbxproj
5. design-system.yaml + docs + `.devin` + pendiente compartido
6. Docs del backend (solo `*.md`)
7. `flutter analyze` + `flutter test` + relanzar en emulador
8. Usuario renombra la carpeta `pcalientes_app` → `depredadog_app` con el IDE
   cerrado; al reabrir, re-indexar el grafo codebase-memory
