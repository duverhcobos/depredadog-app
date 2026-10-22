# Template Flutter

Template de arranque para apps Flutter con **Clean Architecture + SOLID**, `flutter_bloc`, `go_router`, `get_it` y localización `.arb`. Pensado para clonarse al empezar un producto móvil nuevo.

## Qué trae

- Estructura Feature-First (`lib/features/<feature>/{domain,application,infrastructure,presentation}`).
- Workflows de agente: propuestas en `propuestas/`, subagentes implementador/revisor en `.devin/agents/`.
- 19 skills de desarrollo genéricas en `.devin/skills/` (arquitectura, i18n, theming, testing, navegación, etc.).
- `Design/design-system.yaml` — seed v1.0.0, convención de versionado por cambio visual.
- Docs base: `AGENTS.md`, `ENVIRONMENTS.md` (`--dart-define`), `I18N_GUIDE.md`, `APP_ICONS.md`, `promt_solid.md`.

## Cómo usarlo

1. Copiar la carpeta entera y renombrar (`template_flutter` → nombre del producto).
2. `flutter pub get` y verificar `flutter analyze` limpio.
3. Cambiar el `name:` del `pubspec.yaml` (y el package si aplica).
4. Redefinir `Design/design-system.yaml` (paleta/brand) con la primera pantalla real.
5. Revisar `AGENTS.md` — la sección "Producto" apunta a un backend genérico; ajustarla al backend real.

## Backend hermano

`../template_nestj` — template NestJS con DDD + TypeORM + Postgres, mismo workflow de skills/propuestas.
