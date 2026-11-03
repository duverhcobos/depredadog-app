# Propuesta: Shell autenticado — header + nav bar 3 tabs (presentación)

Primer paso del módulo cliente: el marco persistente donde viven las
pantallas autenticadas. **Fase presentación** (screen-first-workflow): sin
domain/data — las acciones del header y los contenidos de cada tab son
placeholders hasta que llegue su módulo.

## Decisiones del usuario (ya tomadas)

- Nav bar: **Inicio · Pedidos · Perfil** (3 tabs) — el carrito va en el
  header, no es sección.
- Header: **imagotipo + campana + carrito** (acciones derecha).
- **Sin hamburguesa** — lo secundario (ajustes, ayuda, logout) vivirá
  dentro del tab Perfil.
- Admin: se construye **después** de terminar el rol cliente — este shell
  es solo de cliente.

## Resumen de cambios

| Archivo | Acción |
|---------|--------|
| `lib/l10n/app_es.arb` | +5 claves: `shellTabHome`, `shellTabOrders`, `shellTabProfile`, `shellNotificationsTooltip`, `shellCartTooltip` → regen `flutter gen-l10n` |
| `lib/core/widgets/app_toast.dart` | agregar `info(context, msg)` — variante neutral (fondo `colorScheme.surfaceContainerHighest`, ícono `info_outline`) para feedback no-éxito/no-error |
| `lib/core/routes/auth_guard.dart` | +2 constantes: `ordersRoute = '/orders'`, `profileRoute = '/profile'` (protegidas automáticas — no van en `defaultPublicRoutes`) |
| `lib/core/screens/module_placeholder_screen.dart` | nuevo — placeholder genérico `{label} — Disponible próximamente` |
| `lib/core/layout/shell_header.dart` | nuevo — header fijo: imagotipo izq + campana + carrito (toast info `comingSoon`, badge carrito mock "2" PROVISIONAL para revisión visual) |
| `lib/core/layout/app_shell_layout.dart` | nuevo — Scaffold: header + `shell` + `NavigationBar` M3 3 destinos |
| `lib/core/routes/app_router.dart` | `/home` GoRoute → `StatefulShellRoute.indexedStack` con 3 branches (`/home`, `/orders`, `/profile`) |
| `lib/core/screens/home_placeholder_screen.dart` | eliminar — reemplazada por la genérica |
| `test/core/layout/app_shell_layout_test.dart` | nuevo — render, 3 destinos, cambio de tab, tooltips |

## 1. `module_placeholder_screen.dart` (nuevo)

```dart
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// Destino provisional de una branch del shell mientras su módulo real
/// no existe (§016). Muestra "{módulo} — Disponible próximamente".
class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({required this.moduleLabel, super.key});

  final String moduleLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(child: Text('$moduleLabel — ${l10n.comingSoon}')),
    );
  }
}
```

## 2. `shell_header.dart` (nuevo)

```dart
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/app_toast.dart';

/// Cabecera fija del shell autenticado (§016): imagotipo a la izquierda,
/// acciones a la derecha. Las acciones son PROVISIONALES — toast
/// "Disponible próximamente" hasta que existan sus módulos
/// (notificaciones / carrito). El badge del carrito es count mock=2
/// PROVISIONAL para la revisión visual — en producción se dibuja solo
/// cuando count>0 y el módulo carrito lo alimenta.
class ShellHeader extends StatelessWidget {
  const ShellHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Image.asset(
              'assets/images/imagotipo_depredadog_dark.png',
              height: 44,
              fit: BoxFit.contain,
              semanticLabel: l10n.appName,
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: l10n.shellNotificationsTooltip,
              onPressed: () => AppToast.info(context, l10n.comingSoon),
            ),
            IconButton(
              // PROVISIONAL: badge con count mock=2 solo para la revisión
              // visual (decisión del usuario). En producción el badge se
              // dibuja cuando count>0 y el módulo carrito lo alimenta.
              icon: const Badge(
                label: Text('2'),
                child: Icon(Icons.shopping_cart_outlined),
              ),
              tooltip: l10n.shellCartTooltip,
              onPressed: () => AppToast.info(context, l10n.comingSoon),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
```

## 3. `app_shell_layout.dart` (nuevo)

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import 'shell_header.dart';

/// Marco persistente del área autenticada (§016): header de marca +
/// contenido del branch activo + NavigationBar de 3 secciones.
/// navigation-routing: entre secciones se navega con goBranch (nunca
/// push — push no mueve currentIndex y el tab quedaría desmarcado).
class AppShellLayout extends StatelessWidget {
  const AppShellLayout({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Column(
        children: [
          const ShellHeader(),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          // Tocar el tab ya activo vuelve a la raíz de esa sección
          // (convención estándar de apps con tabs).
          initialLocation: index == shell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.shellTabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long_rounded),
            label: l10n.shellTabOrders,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: l10n.shellTabProfile,
          ),
        ],
      ),
    );
  }
}
```

## 4. `auth_guard.dart` — +2 constantes

Después de `homeRoute`:

```dart
static const String homeRoute = '/home';
// Secciones del shell autenticado (§016) — protegidas por defecto:
// no entran a defaultPublicRoutes.
static const String ordersRoute = '/orders';
static const String profileRoute = '/profile';
```

## 5. `app_router.dart` — `/home` se convierte en el shell

Reemplazar el GoRoute `/home` actual por:

```dart
// El área autenticada vive dentro de un StatefulShellRoute (§016):
// header + nav bar persistentes. Las pantallas reales de cada módulo
// se declaran como HIJAS de su branch — NUNCA rutas raíz, porque eso
// las sacaría del shell (navigation-routing).
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) =>
      AppShellLayout(shell: navigationShell),
  branches: [
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AuthGuard.homeRoute,
          pageBuilder: (context, state) => CustomTransitions.fade(
            state,
            ModulePlaceholderScreen(
              moduleLabel: AppLocalizations.of(context)!.shellTabHome,
            ),
          ),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AuthGuard.ordersRoute,
          pageBuilder: (context, state) => CustomTransitions.fade(
            state,
            ModulePlaceholderScreen(
              moduleLabel: AppLocalizations.of(context)!.shellTabOrders,
            ),
          ),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: AuthGuard.profileRoute,
          pageBuilder: (context, state) => CustomTransitions.fade(
            state,
            ModulePlaceholderScreen(
              moduleLabel: AppLocalizations.of(context)!.shellTabProfile,
            ),
          ),
        ),
      ],
    ),
  ],
),
```

Más los imports nuevos (`app_shell_layout`, `module_placeholder_screen`,
`app_localizations`) y quitar el de `home_placeholder_screen` (se elimina).

## 6. l10n — 5 claves nuevas en `app_es.arb`

```json
"shellTabHome": "Inicio",
"shellTabOrders": "Pedidos",
"shellTabProfile": "Perfil",
"shellNotificationsTooltip": "Notificaciones",
"shellCartTooltip": "Carrito"
```

Luego `flutter gen-l10n` (los generados no se escriben a mano).

## 7. `app_toast.dart` — variante `info`

Agregar junto a `error`/`success`: misma `_show` con ícono
`info_outline` y fondo neutro (`colorScheme.surfaceContainerHighest` +
texto `onSurface`). Sin ella "Disponible próximamente" tendría que ir
como error o éxito — ambos mienten el tono.

## 8. Tests (`test/core/layout/app_shell_layout_test.dart`)

Con un `GoRouter` mínimo que monte el `StatefulShellRoute` real +
`AppShellLayout` (misma estructura que app_router, sin AuthGuard):
- Renderiza imagotipo + 2 IconButtons (tooltips Notificaciones/Carrito)
  + badge "2" en el carrito + 3 NavigationDestinations.
- Tap en "Pedidos" → muestra "Pedidos — Disponible próximamente" y el
  tab queda seleccionado; volver a "Inicio" idem.
- Tap en campana/carrito → `AppToast` intenta mostrarse (verificar vía
  MethodChannel 'PonnamKarthik/fluttertoast' como en login_screen_test).

## Orden de aplicación

1. `app_es.arb` + `flutter gen-l10n`
2. `app_toast.dart` (info)
3. `auth_guard.dart` (constantes)
4. `module_placeholder_screen.dart`, `shell_header.dart`, `app_shell_layout.dart`
5. `app_router.dart` (shell) + eliminar `home_placeholder_screen.dart`
6. Test nuevo
7. `flutter analyze` + `flutter test`
8. Emulador: login → `/home` con header + tabs → cambio de tabs → toast
   de las acciones → **revisor-ui** → revisión visual del usuario
9. Tras aprobación visual: spec `shell` en `design-system.yaml` (bump +
   changelog + `shellNavBarHeight` — ya referenciado por el spec del
   scroll-top button) + commit
