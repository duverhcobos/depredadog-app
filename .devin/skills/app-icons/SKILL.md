---
name: app-icons
description: Sistema de íconos y splash nativo de Depredadog — ícono launcher FIJO (plato negro + depredador blanco; el modo-dual se descartó por caché de launchers), splash nativo SIN ÍCONO y NEGRO FIJO (MVP solo tema oscuro — la Splash Screen API rasteriza a blur independiente del recurso, y el plato ya no sigue el tema del sistema), capas adaptativas, procedimiento de actualización y fuente del arte (Design/brand/)
triggers:
  - user
  - model
---

# Íconos de la app — cómo configurarlos en Depredadog

Guía de referencia para definir el ícono de Depredadog: qué archivos intervienen,
para qué sirve cada uno y a dónde se copia.

> **Estado actual:** ícono launcher **FIJO** (decisión del usuario, tras
> probar el modo-dual) — isotipo de tintas blancas como
> `VectorDrawable` (`drawable/ic_launcher_foreground.xml`) sobre
> `ic_launcher_background` `#000000`, igual en claro y oscuro.
> Compartidos: `drawable/ic_launcher_monochrome.xml` (silueta —
> themed icons) y `store_assets/` playstore.
>
> **Por qué el launcher es fijo y no por modo:** los calificadores `-night`
> resuelven bien, pero launchers y Settings cachean el ícono sin el modo
> en la clave — el usuario ve una variante aleatoria cacheada que "no
> cambia nada". Confirmado en pruebas del usuario: app-info mostraba el
> ícono night en ambos modos. Android no soporta ícono launcher por tema
> de forma confiable.
>
> **El splash nativo NO tiene ícono** (decisión final del usuario, tras
> comprobar que ni PNG grande ni `VectorDrawable` exacto evitan el blur):
> `android:windowSplashScreenAnimatedIcon` apunta a
> `drawable/splash_icon_empty.xml` (vector 240dp transparente, sin
> paths visibles) — solo queda el plato liso de
> `@drawable/launch_background`. **MVP solo tema oscuro** (decisión
> posterior del usuario): el plato ya no es por tema — `values/styles.xml`
> es el único `styles.xml` (se eliminó `values-night/`), con
> `LaunchTheme`/`NormalTheme` partiendo de `Theme.Black.NoTitleBar` →
> siempre `#000000`, sin depender del brightness del sistema. El primer
> logo que ve el usuario es el del splash **Flutter** (imagotipo PNG vía
> `Image.asset`, Skia puro, sin el pipeline de la Splash Screen
> API). Ver sección "Splash nativo — por qué no tiene ícono".
>
> **Por qué se descartó el ícono del splash nativo (medido, no a ojo):**
> `windowSplashScreenAnimatedIcon` convierte el recurso a un `Icon` y lo
> rasteriza internamente a un bitmap antes de componer la animación de
> reveal — eso produce un borde suavizado. Se midió el perfil de píxeles
> de un mismo borde: PNG `isotipo_icono_*` y `VectorDrawable` 1:1 desde
> el SVG oficial dieron **exactamente la misma transición** (`0→35→140→
> 207→244→253→255`, 6 valores intermedios) vs. el splash Flutter sobre el
> mismo borde (`0→4→59→238→254→255`, salto casi binario en 2px). Cambiar
> el `android:width/height` declarado del vector (288dp→240dp, el spec
> correcto para ícono con plato) no movió ni un byte del resultado — el
> blur es del pipeline de la plataforma (API 31+), no de la resolución,
> el formato ni el tamaño del recurso. No es arreglable desde los
> assets.
>
> **Cuidado al forzar "sin ícono":** omitir
> `windowSplashScreenAnimatedIcon` por completo NO deja la pantalla
> lisa — Android 12+ autocompone el ícono del **launcher** (el fijo,
> negro+blanco redondo) por defecto. Hay que declarar explícitamente un
> drawable transparente (`splash_icon_empty.xml`, 240dp, un `<path>`
> con `fillColor="#00000000"`) para suprimirlo; un vector de 1dp sin
> paths no fue suficiente (el sistema lo descarta y cae al mismo
> fallback del launcher).
>
> **Fuente del arte del launcher — el SVG oficial `Design/brand/svg/`:**
> el foreground/monochrome del launcher usan `VectorDrawable`s generados
> 1:1 desde `isotipo_mascota_.svg` (trazos blancos). El splash ya no usa
> arte (ver arriba); los `isotipo_icono_*` de `Design/brand/png/` siguen
> siendo la fuente de los raster legacy (`ic_launcher.png`/round API<26,
> playstore 512).
>
> **El margen de compensación vive en el vector, no en el arte:** el
> SVG oficial es full-bleed (viewBox 587.843×496.075). El
> `VectorDrawable` del launcher usa viewport 3200×3200 con un `<group>`
> que escala el arte ×3.48573 y lo traslada a (575,736) — replica exacta
> del lienzo con margen ~18%/lado que el usuario diseñó para los PNG
> `isotipo_icono_*`. Arte al ~64% del lienzo → entra sobrado en la zona
> segura del launcher (~61%).
>
> **REGLA DE ARTE — solo PNGs oficiales de `Design/brand/`:** el pack
> viejo `appicon-pack-mascota-color/` contiene una variante del isotipo
> con **borde/contorno negro horneado** que NO es arte oficial (se usó por
> error en el splash claro y el usuario lo revirtió). Nunca copiar
> foregrounds del pack — instanciar siempre los `isotipo_*`/`imagotipo_*`
> originales del kit.
>
> Manifest con `android:icon` + `android:roundIcon`. El kit completo de
> marca vive en `Design/brand/` (png por densidad + svg + pack previo).
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
| `foreground` | `@drawable/ic_launcher_foreground` | El isotipo — `VectorDrawable` (nítido en toda densidad). La zona segura visible es ~el 66% central |
| `monochrome` | `@drawable/ic_launcher_monochrome` | Variante monocromática (solo alfa) — Android 13+ la tiñe con el color del tema del usuario ("themed icons") |

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
- `drawable-night/` **no existe** actualmente — el splash ya no tiene
  arte por modo (sin ícono, ver sección del splash); el ícono launcher
  por modo también se **descartó** (ver nota de estado): los
  calificadores `night` resuelven en el recurso pero launchers/Settings
  cachean el bitmap sin el modo — el usuario ve variantes stale.

Densidades y tamaño del ícono de launcher:

| Carpeta | Densidad | Tamaño típico |
|---------|----------|---------------|
| `mipmap-mdpi` | 1.0× | 48×48 px |
| `mipmap-hdpi` | 1.5× | 72×72 px |
| `mipmap-xhdpi` | 2.0× | 96×96 px |
| `mipmap-xxhdpi` | 3.0× | 144×144 px |
| `mipmap-xxxhdpi` | 4.0× | 192×192 px |

> Las capas `foreground` y `monochrome` son `VectorDrawable` en `drawable/`
> — sin copias por densidad (el vector escala nítido a cualquier tamaño).
> El sistema las dibuja sobre un lienzo ~108dp donde el contenido visible
> es ~72dp; el margen ya viene calculado en la transformación del grupo.

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
| `drawable/ic_launcher_foreground.xml` | `res/drawable/` | Capa foreground del adaptativo — `VectorDrawable` del isotipo blanco |
| `drawable/ic_launcher_monochrome.xml` | `res/drawable/` | Capa monocromática (Android 13+ themed icons) — silueta vectorial |
| `mipmap-{d}/ic_launcher.png` | `res/mipmap-{d}/` | Ícono legacy cuadrado (API <26) — único raster que queda |
| `playstore-icon.png` | `store_assets/ic_launcher-playstore.png` | Ficha de Play Console (512×512) |

`{d}` = `hdpi`, `mdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi` (5 densidades). El
ícono **launcher** es fijo — una sola variante `ic_launcher*` en
`mipmap-{d}/` + `values/` + `drawable/` (la fuente del arte son los SVG
oficiales de `Design/brand/svg/`). El splash **no tiene arte propio** —
solo `drawable/splash_icon_empty.xml` (vector transparente, el mismo en
ambos modos) para suprimir el fallback del launcher — ver la sección del
splash.

### Excepciones del pack

- **`ic_launcher_round.png`**: los generadores no siempre lo emiten (el redondo
  sale del XML adaptativo en API 26+). Si el manifest declara `roundIcon` y hay
  API <26, hay que duplicar `ic_launcher.png` → `ic_launcher_round.png` en cada
  `mipmap-{d}` del destino.
- **`README.txt`**: no se copia — son las instrucciones del generador.

---

## Procedimiento completo de actualización

1. **Fuente de verdad: los SVG oficiales `Design/brand/svg/`** —
   `isotipo_mascota_negro.svg` (positivo, trazos `#030304`) e
   `isotipo_mascota_.svg` (negativo, trazos `#FFF`). Los 22 `pathData`
   se copian 1:1 a cada `VectorDrawable`, mapeando las clases CSS del
   `<style>` (`cls-N` → `fill` declarado; los paths sin clase heredan el
   color de trazo de la variante). Viewport fijo 3200×3200 + grupo
   `translateX/Y=575/736` `scaleX/Y=3.48573` — replica el lienzo con
   margen que el usuario diseñó en los `isotipo_icono_*` (borrar el
   grupo = arte full-bleed → la máscara recorta las garras).
2. Escribir los XML: `drawable/ic_launcher_foreground.xml` (blanco) y
   `drawable/ic_launcher_monochrome.xml` (mismos paths con `fillColor`
   `#FFFFFF` — el sistema tiñe el canal alfa). El splash no usa arte
   (`drawable/splash_icon_empty.xml` es fijo y no se regenera con el
   procedimiento del isotipo).
3. Los legacy `ic_launcher.png`/`ic_launcher_round.png` (`mipmap-{d}`,
   API <26) se componen con PIL desde `isotipo_icono_blanco{d}`: fondo
   `#000000` + arte a tamaño completo. Igual para
   `store_assets/ic_launcher-playstore.png` (512).
4. **Cuidado al escribir los XML desde scripts:** `open()` en Windows usa
   cp1252 por defecto — los comentarios con acentos rompen el parse de
   aapt ("Byte no válido de la secuencia UTF-8"). Escribir siempre con
   `encoding='utf-8'`.
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

## Splash nativo — por qué no tiene ícono, y por qué es negro fijo

La pantalla de arranque (lo que se ve antes del primer frame de Flutter) está
implementada en `res/values/styles.xml` → `LaunchTheme`. Dos decisiones del
usuario se acumulan acá:

1. **Sin ícono.** Se probaron dos generaciones de arte (PNG
   `isotipo_icono_*` de hasta 3200px y `VectorDrawable` 1:1 desde los SVG
   oficiales) y ambas dieron el **mismo resultado de blur**, medido en
   perfil de píxeles — la causa es el pipeline de la Splash Screen API
   (API 31+), no el recurso.
2. **Negro fijo, no por tema** (decisión posterior, MVP solo oscuro — ver
   `app_theme_mode` en `design-system.yaml`): se eliminó `values-night/` y
   `drawable-night-v21/`; `values/styles.xml` es el único `styles.xml` y su
   `LaunchTheme`/`NormalTheme` parten de `Theme.Black.NoTitleBar` en vez de
   `Theme.Light.NoTitleBar` — así `?android:colorBackground` resuelve negro
   siempre, sin depender del brightness del sistema. Evita un flash
   blanco→negro justo antes de que Flutter (ahora `ThemeMode.dark` fijo)
   pinte su primer frame.

| Atributo (API 31+) | Valor | Qué hace |
|--------------------|-------|----------|
| `android:windowSplashScreenAnimatedIcon` | `@drawable/splash_icon_empty` | Vector 240dp **transparente** (un `<path>` con `fillColor="#00000000"`, sin arte visible) — necesario para suprimir el ícono; ver nota abajo |
| `android:windowBackground` | `@drawable/launch_background` | Fondo de la ventana (plato liso) — `drawable-v21` resuelve `?android:colorBackground`, que ahora siempre es negro vía el `LaunchTheme` unificado |

El resultado: **ventana lisa negra** siempre, sin logo — el primer logo que
ve el usuario es el del **splash Flutter** (imagotipo PNG vía
`Image.asset`, renderizado con Skia, sin pasar por el pipeline de
`Icon`/bitmap de la plataforma), que además vuela con un `Hero` hacia el
header del login (ver `lib/core/constants/hero_tags.dart`).

> **Por qué se descartó el ícono (evidencia, no intuición):** se midió el
> perfil de píxeles de un mismo borde (la garra del isotipo) en tres
> variantes: PNG `isotipo_icono_*` 3200px, `VectorDrawable` generado 1:1 del
> SVG oficial, y la imagen del splash Flutter. Las dos primeras dieron
> **exactamente la misma transición byte a byte** (`0→35→140→207→244→253→
> 255`, 6 valores intermedios — blur real) mientras que el splash Flutter
> dio un salto casi binario (`0→4→59→238→254→255`, 2px). Cambiar
> `android:width/height` del vector (288dp→240dp, el valor correcto del
> spec oficial para ícono con plato) no movió ni un byte del resultado —
> descarta que fuera un problema de tamaño declarado. La causa es que
> `windowSplashScreenAnimatedIcon` convierte el recurso a un `Icon` de
> Android y lo rasteriza/escala internamente antes de la animación de
> reveal, sin importar si la fuente es PNG o vector. Es una limitación de
> la plataforma, no arreglable desde los assets.

> **Por qué el drawable vacío tiene que ser de 240dp y no de 1dp:** omitir
> `windowSplashScreenAnimatedIcon` por completo NO deja la pantalla lisa —
> Android 12+ autocompone el ícono del **launcher** (fijo, negro+blanco
> redondo) como fallback por defecto. Probar con un vector de 1dp sin paths
> tampoco bastó — el sistema lo descarta por "inválido" y cae al mismo
> fallback. Un vector de tamaño normal (240dp, viewport 240×240) con un
> `<path>` de `fillColor` completamente transparente sí es aceptado como
> ícono "real" (aunque invisible) y el sistema no sustituye nada.

Nota de verificación: los launchers cachean íconos compuestos — si tras un
cambio al ícono del **launcher** no se actualiza, es caché del launcher (no
del recurso); basta reiniciar el launcher (en el emulador: `pm clear` al
nexuslauncher) o desinstalar/reinstalar. El splash no tiene ese problema:
se re-resuelve en cada arranque (por eso la decisión "sin ícono" surte
efecto inmediato sin depender de caché).

## Assets relacionados (por crear)

| Archivo | Rol |
|---------|-----|
| `assets/images/imagotipo_app.png` | Imagotipo completo (símbolo + palabra) — splash y headers |
| `assets/images/app_isotipo.png` | Solo el isotipo — fuente para generar íconos |
| `isotipo_app/` | Pack de íconos generado (fuente de verdad de esta config) |
