# Pendientes pre-producción — Depredadog App

Ítems accionables del lado **frontend/app** que hoy funcionan como workaround de dev/MVP pero deben resolverse — o aceptarse explícitamente — antes del deploy. Ver skill `pendientes-produccion` para formato y estados.

> Convención (decisión del usuario): **cada repo tiene su propia `pendientes/`** — esta carpeta es la del repo app. Los ítems del backend viven en `../pcalientes_backend/pendientes/`.

| # | Ítem | Estado | Bloqueo |
|---|------|--------|---------|
| 001 | [Crashlytics / logger de producción en la app](001-crashlytics-app.md) | 🔴 PENDIENTE | bloqueante |
| 002 | [Identidad de marca completa (imagotipo + iOS) y commit del frente](002-identidad-marca.md) | 🔴 PENDIENTE | bloqueante iOS / recomendado Android |
| 003 | [Release Android: firma, INTERNET en main, minify](003-release-android.md) | 🔴 PENDIENTE | bloqueante |
| 004 | [Release iOS: firma, íconos, TestFlight](004-release-ios.md) | 🔴 PENDIENTE | bloqueante iOS |
| 005 | [Presencia en tiendas: privacy, data safety, listings](005-store-presence.md) | 🔴 PENDIENTE | bloqueante distribución pública |
| 006 | [Google OAuth prod: client IDs + SHA-1 release](006-google-oauth.md) | 🔴 PENDIENTE | condicional (si Google login entra al MVP) |
| 007 | [Restaurar sesión al abrir la app](007-restaurar-sesion.md) | 🟢 RESUELTO | recomendado |
| 008 | [Expulsión de sesión a mitad de uso no navega sola](008-expulsion-mid-session.md) | 🔴 PENDIENTE | recomendado |
| 009 | [Catálogo real de toppings y salsas (datos de negocio)](009-catalogo-toppings-salsas-real.md) | � RESUELTO | bloqueante |
| 010 | [Extraer widgets del detalle de producto (umbral de tamaño)](010-extraer-widgets-detalle-producto.md) | 🔴 PENDIENTE | recomendado |
| 011 | ["Gratis" en el copy del carrusel de promos](011-copy-gratis-carrusel-promos.md) | 🔴 PENDIENTE | menor |
| 012 | [Fallback ciego 409 en auth puede etiquetar mal un rechazo](012-fallback-409-ciego-auth.md) | 🔴 PENDIENTE | condicional (Google OAuth / otros 409) |
| 013 | [Nueva orden presencial (form del FAB de Cocina)](013-nueva-orden-presencial.md) | 🟢 RESUELTO | bloqueante para operación presencial desde la app |
| 014 | [Historial definitivo de Cocina (ubicación, paginación, cierres)](014-historial-definitivo.md) | 🔴 PENDIENTE | recomendado |
| 015 | [Campo nota opcional en el cierre de caja](015-nota-cierre-caja.md) | 🔴 PENDIENTE | menor |
| 016 | [Refresh del catálogo en home (CatalogCubit singleton)](016-refresh-catalogo-home.md) | 🔴 PENDIENTE | recomendado |
| 017 | [Combos en la app — carta ya decidida por el dueño](017-combos-carta.md) | 🔴 PENDIENTE | post-MVP |
