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
