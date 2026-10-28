# Pendiente: Definir la identidad de marca completa (imagotipo + iOS)

> **Estado: � EN PROGRESO** — frente Android commiteado y verificado; queda iOS + visto bueno final
> **Producto:** frontend
> **Bloqueo:** bloqueante para iOS (sin `AppIcon.appiconset` de marca no hay release iOS); Android ya resuelto

## Contexto

El kit de identidad ya está integrado y verificado en emulador:

- `Design/brand/` — PNGs ×6 densidades + SVGs fuente + pack previo `appicon-pack-mascota-color/` (registro)
- Ícono launcher Android **fijo**: isotipo negativo como `VectorDrawable` sobre `#000000` — el modo-dual se descartó tras pruebas del usuario (launchers/Settings cachean el ícono por tema; skill `app-icons` documenta el porqué)
- Splash nativo **sin ícono y negro fijo** (dos decisiones del usuario): se probó PNG grande y VectorDrawable exacto del SVG oficial, ambos dieron el mismo blur medido en perfil de píxeles — es la Splash Screen API la que rasteriza internamente, no el recurso. Solo queda el plato liso; MVP solo tema oscuro → el plato ya no es por tema, es `#000000` fijo (se eliminó `values-night/`); el primer logo nítido es el del splash Flutter
- MVP solo tema oscuro: `MaterialApp.router` con `ThemeMode.dark` fijo — AppTheme.light()/AppColors *Light quedan en el repo sin usarse
- Splash Flutter: imagotipo real centrado (siempre variante oscura por el punto anterior) en `Hero(tag: HeroTags.brandImagotipo)` — vuela al header del login al navegar, ~800ms tras decodificar la imagen
- Compartidos: `ic_launcher_monochrome` (themed icons), `ic_launcher_round`, `store_assets/` playstore 512 — legacy raster para API<26
- Margen de compensación ~18%/lado (launcher): migrado al `<group>` del VectorDrawable (viewport 3200², scale 3.48573, translate 575/736) que replica el lienzo de `isotipo_icono_*`
- Docs: skill `app-icons` (fuente de verdad del mecanismo) + `design-system.yaml` v1.7.0

## Qué falta

- **Íconos iOS** — el pack suministrado solo traía Android; falta generar/exportar el set iOS y poblar `AppIcon.appiconset`.
- **Visto bueno final** a la marca completa (imagotipo ya integrado en splash Flutter y header del login con variante por tema).
- ~~**Imagotipo en splash**~~ — hecho: `SplashScreen` usa el imagotipo real por tema (ya no `AppBrandMark`/flama, eliminados).
- ~~**Commit del frente de marca**~~ — hecho en `b1c7b39` (ícono fijo negro + kit `Design/brand/` + `roundIcon` + styles); la separación splash-por-tema va en el commit siguiente.

## Criterio de cierre

- ~~Imagotipo integrado en splash con la variante correcta por tema.~~ Hecho.
- `AppIcon.appiconset` poblado con el isotipo en iOS.
- Usuario aprueba la marca completa.
