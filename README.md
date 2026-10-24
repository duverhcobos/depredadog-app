# Depredadog — App

App móvil de **Depredadog** en Flutter con **Clean Architecture + SOLID**, `flutter_bloc`, `go_router`, `get_it` y localización `.arb`. Cliente único del backend `../pcalientes_backend`.

## Qué trae

- Estructura Feature-First (`lib/features/<feature>/{domain,data,presentation}`).
- Workflows de agente: propuestas en `propuestas/`, subagentes implementador/revisor en `.devin/agents/`.
- 19 skills de desarrollo en `.devin/skills/` (arquitectura, i18n, theming, testing, navegación, etc.).
- `Design/design-system.yaml` — fuente de verdad de la identidad visual (versionado por cambio visual).
- Docs base: `AGENTS.md`, `ENVIRONMENTS.md` (`--dart-define`), `I18N_GUIDE.md`, `APP_ICONS.md`, `promt_solid.md`.

## Setup

1. `flutter pub get` y verificar `flutter analyze` limpio.
2. `flutter run --dart-define=ENV=dev` — ver `ENVIRONMENTS.md` para apuntar al backend local.

El core ya está bootstrapeado (propuesta `001-app-bootstrap`): environment, DI (`get_it`), `dio` tras `INetworkService`, `flutter_secure_storage`, `go_router` + `AuthGuard`, tema Material 3 con la paleta de condimentos y localización `es`. Las features nuevas siguen `new-feature-checklist` dentro de `lib/features/`.

## Backend hermano

`../pcalientes_backend` — API NestJS con DDD + TypeORM + Postgres (`:3000`), mismo workflow de skills/propuestas. Las carpetas compartidas `pendientes/` y `planeaciones/` viven en su raíz.
