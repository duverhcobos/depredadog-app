---
name: app-icons
description: Sistema de íconos y splash nativo de Depredadog — ícono FIJO (plato negro + depredador blanco; el modo-dual se descartó por caché de launchers), capas adaptativas, procedimiento de actualización y fuente del arte (Design/brand/)
triggers:
  - user
  - model
---

# Íconos de la app — cómo configurarlos en Depredadog

Guía de referencia para definir el ícono de Depredadog: qué archivos intervienen,
para qué sirve cada uno y a dónde se copia.

> **Estado actual:** ícono **FIJO** (decisión del usuario, tras probar el
> modo-dual) — `isotipo_mascota` (versión negativa, tintas blancas) sobre
> `ic_launcher_background` `#000000`, igual en claro y oscuro. Implementado
> sin calificadores: `mipmap-{d}/` y `values/`→`#000000` únicos (los
> `mipmap-night-{d}/` y `values-night/ic_launcher_background.xml` se
> eliminaron). Compartidos: `ic_launcher_monochrome` (silueta de
> `isotipo_blanco` — themed icons) y `store_assets/` playstore.
>
> **Por qué fijo y no por modo:** los calificadores `-night` resuelven
> bien, pero launchers y Settings cachean el ícono sin el modo en la clave
> — el usuario ve una variante aleatoria cacheada que "no cambia nada".
> Confirmado en pruebas del usuario: app-info mostraba el ícono night en
> ambos modos. Android no soporta ícono por tema de forma confiable.
> Generado con System.Drawing desde `Design/brand/png/4x/` — foreground
> 70%, legacy 82%, playstore 86%. Manifest con `android:icon` +
> `android:roundIcon`. El kit completo de marca vive en `Design/brand/`
> (png por densidad + svg + pack previo `appicon-pack-mascota-color/`).
> **Pendiente:** el set de iOS (ver sección "Pendiente — iOS") — ver
> `pendientes/002-identidad-marca.md`.

---

## Cómo funciona el sistema de íconos en Android

Android usa **dos sistemas de ícono coexistiendo**, según la versión del
dispositivo:

### 1. Íconos adaptativos (API 26+, Android 8.0+)

En vez de una imagen fija, el ícono se compone de **capas** que el sistema
combina y recorta según la forma del launcher (círculo, squircle, gota…):

| Capa | Recurso | Qué es |
|------|---------|--------|
| `background` | `@color/ic_launcher_background` | Fondo — color plano de marca |
| `foreground` | `@mipmap/ic_launcher_foreground` | El isotipo — PNG transparente dibujado más grande que el ícono final (la zona segura visible es ~el 66% central) |
| `monochrome` | `@mipmap/ic_launcher_monochrome` | Variante monocromática (solo alfa) — Android 13+ la tiñe con el color del tema del usuario ("themed icons") |

Los **descriptores** son XML en `res/mipmap-anydpi-v26/`:

- `ic_launcher.xml` — define el ícono adaptativo estándar (background + foreground + monochrome).
- `ic_launcher_round.xml` — la variante para launchers que piden forma circular.

`anydpi` significa "cualquier densidad": un solo XML sirve para todas las
pantallas — el sistema escoge el PNG de capa de la densidad adecuada.

### 2. PNGs legacy (API < 26)

Los dispositivos con Android 7.x e inferiores **no entienden** los XML
adaptativos y necesitan el ícono ya renderizado:

- `res/mipmap-{density}/ic_launcher.png` — ícono cuadrado completo, pre-renderizado
  por densidad de pantalla.
- `res/mipmap-{density}/ic_launcher_round.png` — variante redonda, usada por
  launchers circulares cuando el manifest declara `android:roundIcon`.
- ~~`res/mipmap-night-{density}/`~~ — el ícono por modo se **descartó**
  (ver nota de estado): los calificadores `night` resuelven en el recurso
  pero launchers/Settings cachean el bitmap sin el modo — el usuario ve
  variantes stale, no el cambio de tema.

Densidades y tamaño del ícono de launcher:

| Carpeta | Densidad | Tamaño típico |
|---------|----------|---------------|
| `mipmap-mdpi` | 1.0× | 48×48 px |
| `mipmap-hdpi` | 1.5× | 72×72 px |
| `mipmap-xhdpi` | 2.0× | 96×96 px |
| `mipmap-xxhdpi` | 3.0× | 144×144 px |
| `mipmap-xxxhdpi` | 4.0× | 192×192 px |

> Los PNGs de `foreground` y `monochrome` en cada `mipmap-*` son las **capas**
> para los XML adaptativos — van más grandes que el ícono final (~108dp de lienzo,
> ~72dp de contenido visible).

### 3. Referencias en el manifest

`android/app/src/main/AndroidManifest.xml`:

```xml
<application
    android:label="Depredadog"
    android:icon="@mipmap/ic_launcher"
    android:roundIcon="@mipmap/ic_launcher_round">
```

En API ≥26, `@mipmap/ic_launcher` y `@mipmap/ic_launcher_round` resuelven a los
XML de `mipmap-anydpi-v26/`; en API <26 resuelven a los PNG de `mipmap-*/`.

### 4. Ícono de la Play Store

`store_assets/ic_launcher-playstore.png` — 512×512, **no se compila en el APK**:
es el asset que se sube a Play Console para la ficha de la tienda. Vive fuera de
`res/` a propósito.

---

## Mapa de archivos: qué se copia y por qué

Pack generado (carpeta `isotipo_app/android/res/` o equivalente):

| Origen (pack) | Destino (proyecto) | Para qué |
|---------------|--------------------|----------|
| `mipmap-anydpi-v26/ic_launcher.xml` | `android/app/src/main/res/mipmap-anydpi-v26/` | Descriptor adaptativo estándar |
| `mipmap-anydpi-v26/ic_launcher_round.xml` | `android/app/src/main/res/mipmap-anydpi-v26/` | Descriptor adaptativo redondo |
| `values/ic_launcher_background.xml` | `android/app/src/main/res/values/` | Color de fondo del adaptativo (definir con la paleta de Depredadog) |
| `mipmap-{d}/ic_launcher.png` | `res/mipmap-{d}/` | Ícono legacy cuadrado (API <26) |
| `mipmap-{d}/ic_launcher_foreground.png` | `res/mipmap-{d}/` | Capa foreground del adaptativo |
| `mipmap-{d}/ic_launcher_monochrome.png` | `res/mipmap-{d}/` | Capa monocromática (Android 13+ themed icons) |
| `playstore-icon.png` | `store_assets/ic_launcher-playstore.png` | Ficha de Play Console (512×512) |

`{d}` = `hdpi`, `mdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi` (5 densidades). El
ícono es fijo — una sola variante en `mipmap-{d}/` + `values/` (la fuente
del arte está en `Design/brand/png/4x/`).

### Excepciones del pack

- **`ic_launcher_round.png`**: los generadores no siempre lo emiten (el redondo
  sale del XML adaptativo en API 26+). Si el manifest declara `roundIcon` y hay
  API <26, hay que duplicar `ic_launcher.png` → `ic_launcher_round.png` en cada
  `mipmap-{d}` del destino.
- **`README.txt`**: no se copia — son las instrucciones del generador.

---

## Procedimiento completo de actualización

1. Generar el pack con la imagen fuente del isotipo (ej.
   [appicon.ikit.app](https://appicon.ikit.app) o `flutter_launcher_icons` si se
   prefiere vía pubspec), o componer manualmente con System.Drawing desde
   `Design/brand/png/4x/` (arte actual: `isotipo_mascota`, negativa).
2. Copiar todo el contenido de `<pack>/android/res/` dentro de
   `android/app/src/main/res/` (merge + sobrescribir) — sin variantes
   `-night` (ícono fijo).
3. En cada `android/app/src/main/res/mipmap-{d}/`, duplicar
   `ic_launcher.png` → `ic_launcher_round.png` si el pack no lo trae.
4. Copiar `<pack>/android/res/playstore-icon.png` →
   `store_assets/ic_launcher-playstore.png`.
5. Verificar `AndroidManifest.xml`: `android:label`, `android:icon`,
   `android:roundIcon` apuntando a los recursos correctos.
6. Desinstalar la app del dispositivo y `flutter run` — el launcher cachea el
   ícono y una reinstalación encima puede no refrescarlo.

## Pendiente — iOS

`ios/Runner/Assets.xcassets/AppIcon.appiconset/` sigue con el ícono default de
Flutter. El sistema iOS no usa capas adaptativas: necesita un set de PNGs
cuadrados sin transparencia en tamaños fijos (16×16 a 1024×1024). Se genera con
el mismo isotipo en el generador (exportar bundle iOS) o con
`flutter_launcher_icons`. Cuando exista el pack iOS: reemplazar los PNGs del
`AppIcon.appiconset` conservando el `Contents.json`.

## Splash nativo por modo (claro/oscuro)

La pantalla de arranque (lo que se ve antes del primer frame de Flutter) está
implementada por modo en `res/values{,-night}/styles.xml` → `LaunchTheme`:

| Atributo (API 31+) | Valor | Qué hace |
|--------------------|-------|----------|
| `android:windowSplashScreenAnimatedIcon` | `@mipmap/ic_launcher_foreground` | Fuerza el **foreground transparente** (no el ícono legacy cuadrado) — ícono fijo: depredador blanco en ambos modos |
| `android:windowSplashScreenIconBackgroundColor` | `@color/ic_launcher_background` | El "plato" circular del ícono — `#000000` fijo (igual que el launcher icon) |
| `android:windowBackground` | `@drawable/launch_background` | Fondo de la ventana — blanco claro / `?colorBackground` (negro) oscuro |

El resultado: la **ventana** del splash sí sigue el tema (clara u oscura),
pero el **ícono + plato** son fijos (negro + depredador blanco), igual que
el ícono de launcher — consistente en cualquier modo.

> **Por qué `windowSplashScreenAnimatedIcon` explícito:** sin él, el sistema
> resuelve el ícono por densidad y puede dibujar el PNG **legacy** (cuadrado
> opaco) dentro del plato — se veía como "círculo blanco con cuadrado negro".
> Con el foreground transparente el plato queda detrás del arte y el resultado
> es el isotipo limpio sobre el color de fondo en ambos modos.

Nota de verificación: los launchers cachean íconos compuestos — si tras un
cambio el ícono no se actualiza, es caché del launcher (no del recurso);
basta reiniciar el launcher (en el emulador: `pm clear` al nexuslauncher)
o desinstalar/reinstalar. Fue exactamente esta limitación la que descartó
el ícono por modo.

## Assets relacionados (por crear)

| Archivo | Rol |
|---------|-----|
| `assets/images/imagotipo_app.png` | Imagotipo completo (símbolo + palabra) — splash y headers |
| `assets/images/app_isotipo.png` | Solo el isotipo — fuente para generar íconos |
| `isotipo_app/` | Pack de íconos generado (fuente de verdad de esta config) |
