---
name: ui-design-standard
description: Estándar de diseño de interfaces (theming, espaciado, componentes reutilizables, patrones de pantalla) en la app
triggers:
  - user
  - model
---

Estándar de UI para **la app**. Aplica al crear o modificar cualquier pantalla/widget
en `presentation/`. El objetivo es que toda pantalla nueva se vea y se comporte de forma
consistente con `LoginScreen`/`ForgotPasswordScreen`, sin reinventar patrones.

## Theming — cero valores quemados

- **Nunca** usar `Colors.blue`, `Colors.red`, `Colors.green`, etc. directamente en una pantalla o
  widget. Usar siempre `Theme.of(context).colorScheme.<rol>` (`primary`, `error`, `surface`, etc.)
  o las constantes de `lib/core/theme/app_colors.dart` (`AppColors`).
  - Éxito / información positiva → `Theme.of(context).colorScheme.primary`.
  - Error / fallo → `Theme.of(context).colorScheme.error`.
- Los únicos archivos autorizados a mencionar `Colors.*` directamente son `app_theme.dart` y
  `app_colors.dart` (la abstracción centralizada). Si necesitas un color nuevo, agrégalo ahí, no en
  la pantalla que lo consume.
- El tema debe seguir soportando `ThemeMode.system` (light + dark) — cualquier color nuevo se
  define para ambos (`...Light` y `...Dark` en `AppColors`).

## Espaciado y layout — escala consistente

- Padding estándar de contenido de pantalla: `EdgeInsets.all(24.0)` dentro de un
  `SingleChildScrollView` centrado (`Center` → `SingleChildScrollView` → `Column`).
- Separación vertical entre elementos con `SizedBox(height: N)`, usando esta escala (no valores
  arbitrarios): `8` (relación estrecha, ej. label-error), `12` (entre botones relacionados), `16`
  (entre campos de formulario), `24` (entre bloques), `32` (antes/después de un bloque de texto
  explicativo o para separar secciones grandes).
- Tamaño de fuente de texto de cuerpo/explicativo: `16`. Texto de estado destacado (ej. mensaje de
  bienvenida, loading): `18`.
- Iconos decorativos grandes (splash, pantallas de estado): `size: 80`, coloreados con
  `Theme.of(context).colorScheme.primary`.

## Estructura de pantalla — patrón obligatorio

Toda pantalla que dependa de un Cubit local sigue este patrón de dos clases (visto en
`LoginScreen`/`ForgotPasswordScreen`):

```dart
class XScreen extends StatelessWidget {
  const XScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<XCubit>(
      create: (context) => locator<XCubit>(),
      child: const _XView(),
    );
  }
}

class _XView extends StatelessWidget {
  const _XView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // ... UI reactiva a XCubit
  }
}
```

- La clase pública (`XScreen`) solo resuelve el Cubit vía `locator` y lo provee — no contiene UI.
- La clase privada (`_XView`) es la que realmente construye la interfaz y lee el estado.

## Componentes reutilizables

- **Campos de texto:** siempre usar `CustomTextField` (`lib/features/auth/presentation/widgets/`),
  nunca un `TextFormField` crudo duplicado en cada pantalla. Pasar `errorText` desde el estado del
  Cubit (`state.campo.displayError != null ? l10n.claveError : null`), nunca calcular el error en
  el widget.
- **Botón de acción primaria:** `SizedBox(width: double.infinity, child: ElevatedButton(...))`.
- **Acción secundaria (ej. login alternativo):** `OutlinedButton.icon(icon: ..., label: ...)`.
- **Estado de carga en botones:** mientras `status.isInProgress`, reemplazar la columna de botones
  completa por un único `CircularProgressIndicator()` centrado — no deshabilitar el botón dejándolo
  visible con un spinner adentro.
- **Feedback de éxito/error:** `AppToast` (`lib/core/widgets/app_toast.dart`, sobre fluttertoast) —
  `AppToast.error(context, l10n.clave)` / `AppToast.success(context, l10n.clave)`, siempre disparado
  desde un `BlocListener` (nunca desde dentro del `build` condicional). **Nunca** `ScaffoldMessenger`
  /`SnackBar` directo — decisión del usuario (§005): el toast es el único canal de feedback efímero
  de la app. OJO: los toasts no pintan en el árbol de widgets — en tests se verifica interceptando el
  `MethodChannel('PonnamKarthik/fluttertoast')` (ver `login_screen_test.dart`).
- **Botón "volver arriba" en listados largos:** usar `AppScrollTopButton`
  (`lib/core/widgets/app_scroll_top_button.dart`) — círculo de marca 44px + `arrow_upward_rounded`
  blanco, aparece con fade+scale al pasar ~600px de scroll, `animateTo(0)` al tap, tooltip
  `l10n.scrollToTop`. Vive siempre en el árbol (oculto = `opacity: 0` + `IgnorePointer`, para que
  el fade de salida anime). Posicionamiento — spec `scroll_top_button` del yaml:
  - Esquina inferior derecha libre → `Positioned(right: 24, bottom: shellNavBarHeight + 16)`.
  - Esquina ocupada por un FAB de 56px → **apilado encima**: `bottom: shellNavBarHeight + 16 +
    AppScrollTopButton.fabHeight + .stackGap`, centrado en el eje del FAB (`right: 24 + 6`),
    y `visible: false` mientras el speed dial esté abierto (`onOpenChanged`) porque sus acciones
    suben por la misma columna. Referencia: el primer listado con FAB que la implemente.
  - El `setState` del umbral solo dispara en la transición (comparar con el bool previo), no por
    cada pixel del scroll.

## Scroll en páginas de módulo — un solo scroll bajo el header

En una página con cabecera de marca de módulo fija, **todo el contenido bajo la cabecera rueda junto
en un único `ListView`** (hero, buscador, card de filas, estados loading/error/vacío, footer de
paginación) — convención vigente: el listado no vive en una caja con scroll propio y
nada queda fijo entre el header y el contenido. Los estados no-lista también son hijos del
scroll, así el pull-to-refresh funciona en todos. El `ScrollController` lo posee la screen para
paginación (`loadMore` cerca del fondo) y para el botón "volver arriba".

## Reactividad — evitar rebuilds innecesarios

- `BlocBuilder` con `buildWhen` acotado al campo específico que le interesa a ese widget (ej.
  `previous.email != current.email` para el campo de email), no un `BlocBuilder` genérico que
  reconstruya todo ante cualquier cambio de estado.
- `BlocListener`/`MultiBlocListener` con `listenWhen` acotado al cambio de `status` (o al tick del
  efecto concreto), para no disparar toasts repetidos — o peor, toasts falsos en transiciones
  ajenas (bug §005: `state.tick > 0` disparaba en cualquier transición; lo correcto es
  `prev.tick != curr.tick` por listener).
- Antes de una acción que dispara un submit, hacer `FocusScope.of(context).unfocus()` para cerrar
  el teclado.

## Texto e i18n

- Ningún `Text('...')` literal — todo pasa por `AppLocalizations` (ver skill `i18n-workflow`).
- Tooltips de `IconButton` también deben venir de `l10n`, no quedar sin tooltip ni hardcodeados.

## Transiciones de navegación

- Usar `CustomTransitions` (`lib/core/routes/custom_transitions.dart`) al declarar `pageBuilder` en
  `AppRouter`, nunca `MaterialPageRoute` ni transiciones ad-hoc dentro de una pantalla. `fade` para
  transiciones neutras/splash, `slideUp` para pantallas que se sienten como un flujo modal (ej.
  login).
