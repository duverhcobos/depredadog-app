# Depredadog — App

App móvil de **Depredadog** en Flutter con **Clean Architecture + SOLID**, `flutter_bloc`, `go_router`, `get_it` y localización `.arb`. Cliente único del backend `../pcalientes_backend`.

## Qué trae

- Estructura Feature-First (`lib/features/<feature>/{domain,application,infrastructure,presentation}`).
- Workflows de agente: propuestas en `propuestas/`, subagentes implementador/revisor en `.devin/agents/`.
- 19 skills de desarrollo en `.devin/skills/` (arquitectura, i18n, theming, testing, navegación, etc.).
- `Design/design-system.yaml` — fuente de verdad de la identidad visual (versionado por cambio visual).
- Docs base: `AGENTS.md`, `ENVIRONMENTS.md` (`--dart-define`), `I18N_GUIDE.md`, `APP_ICONS.md`, `promt_solid.md`.

## Setup

1. `flutter pub get` y verificar `flutter analyze` limpio.
2. `flutter run --dart-define=ENV=dev` — ver `ENVIRONMENTS.md` para apuntar al backend local.
3. Redefinir `Design/design-system.yaml` (paleta/brand) con la primera pantalla real.
4. Las dependencias de arquitectura (bloc, go_router, get_it, dio…) se agregan al `pubspec.yaml` con la primera feature — las skills `flutter-architecture` y `new-feature-checklist` describen el stack objetivo.

## Backend hermano

`../pcalientes_backend` — API NestJS con DDD + TypeORM + Postgres (`:3000`), mismo workflow de skills/propuestas. Las carpetas compartidas `pendientes/` y `planeaciones/` viven en su raíz.
