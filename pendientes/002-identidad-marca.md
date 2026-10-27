# Pendiente: Definir la identidad de marca completa (imagotipo + iOS) y commitear el frente de marca

> **Estado: 🔴 PENDIENTE** — íconos/splash por modo implementados y verificados en Android, pero **sin commitear** a decisión del usuario hasta que la marca quede definida por completo
> **Producto:** frontend
> **Bloqueo:** bloqueante para iOS (sin `AppIcon.appiconset` de marca no hay release iOS); recomendado para Android (íconos ya funcionan)

## Contexto

El kit de identidad ya está integrado y verificado en emulador:

- `Design/brand/` — PNGs ×6 densidades + SVGs fuente + pack previo `appicon-pack-mascota-color/` (registro)
- Ícono Android **por modo**: claro = `isotipo_mascota_negro` sobre `#FFFFFF`, oscuro = `isotipo_mascota` sobre `#000000` (calificadores `mipmap-night-*` + `values-night`)
- Splash nativo por modo: `windowSplashScreenAnimatedIcon` = foreground transparente + `windowSplashScreenIconBackgroundColor` por modo
- Compartidos: `ic_launcher_monochrome` (themed icons), `ic_launcher_round`, `store_assets/` playstore 512
- Docs: skill `app-icons` (fuente de verdad del mecanismo) + `design-system.yaml` v1.2.0

**Todo el frente está en el working tree sin commitear** — el usuario decidió diferir el commit hasta que la marca quede cerrada.

## Qué falta

- **Imagotipo** en splash/welcome — hoy `AppBrandMark` es la flama provisional. El kit ya tiene variantes: `imagotipo_blanco_1` (vertical/horizontal, fondos oscuros) e `imagotipo_negro` (fondos claros) → `assets/images/` + reemplazo de `AppBrandMark` + spec en design-system.
- **Íconos iOS** — el pack suministrado solo traía Android; falta generar/exportar el set iOS y poblar `AppIcon.appiconset`.
- **Visto bueno final** a la marca (tagline "HOT DOGS & MÁS" de la guía vs. texto provisional del splash).
- **Commit del frente de marca** una vez aprobado — incluye también `roundIcon` en manifest, `values{,-night}/styles.xml` y la carpeta `Design/brand/`.

## Criterio de cierre

- Imagotipo integrado en splash/welcome con la variante correcta por tema.
- `AppIcon.appiconset` poblado con el isotipo en iOS.
- Usuario aprueba la marca completa → commit del frente de marca.
