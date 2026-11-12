# Propuesta: Carta pública para invitados — auth por demanda

Hoy **toda** el área del shell exige sesión: sin login no hay carta.
El usuario quiere la vitrina abierta — ver el menú sin cuenta — y que
la auth se pida **solo cuando la acción la requiera** (como en cualquier
app de QSR/e-commerce).

Depende del backend `020` (`@Public()` en `GET /catalog` + `GET
/store/config`) — el orden físico de implementación: backend primero
(la app invitada pega a endpoints hoy protegidos), esta propuesta
después. La propuesta cubre **ambos**: la sección backend va aquí
porque el cambio es de una línea por controller; el commit del backend
queda referenciado.

## Decisiones del usuario (encuesta respondida)

1. **El invitado llega hasta el checkout**: navega la carta, personaliza
   productos, agrega al carrito y lo ve completo. `/home/cart/checkout`
   es la primera ruta protegida — tocar "Ir a pagar" sin sesión →
   `redirect` a `/login?from=/home/cart/checkout`. El carrito sobrevive
   (CartCubit lazySingleton de proceso).
2. **Tabs protegidos = muro de auth DENTRO del tab** (no redirect):
   Pedidos y Perfil siguen existiendo como tabs pero un invitado ve una
   pantalla de estado con CTA a login. El nav de 3 tabs no cambia de
   forma.
3. **Perfil de invitado = muro + "El negocio"** (decisión del usuario,
   "perfil no pero sí puede mostrar la información del negocio"): sin
   identidad/loyalty/Mi cuenta/logout, pero sí la sección "El negocio"
   — "El local" (horarios, abierto/cerrado, dirección, teléfono) y
   "Soporte" son info pública que le sirve a cualquiera.
   `/profile/store` pasa a ruta pública.
4. **Retorno post-login = de vuelta a donde estaba**: el redirect lleva
   `?from=<ruta>`; login/register/verify lo honran (`go(from)` en vez de
   `go(home)`). El guard sanitiza: solo se honra `from` que empiece por
   `/` (anti open-redirect, aunque en móvil es teórico).

## Mapa de rutas resultante

| Ruta | Invitado | Con sesión |
|------|----------|-----------|
| `/` splash | → /home (cambio: hoy → /login) | → /home |
| `/home` + `category/:slug` + `product/:slug` | ✅ carta completa | ✅ |
| `/home/cart` + `/home/cart/edit` | ✅ carrito local | ✅ |
| `/home/cart/checkout` | ⛔ → `/login?from=…` | ✅ |
| `/orders` (tab) | ✅ muro en el tab | ✅ lista real |
| `/orders/:id` | ⛔ → `/login?from=…` | ✅ |
| `/profile` (tab) | ✅ muro + "El negocio" | ✅ perfil real |
| `/profile/store` | ✅ info pública | ✅ |
| `/profile/data` `/profile/addresses*` `/profile/password` | ⛔ → `/login?from=…` | ✅ |
| `/login` `/register` `/verify-email` `/forgot-password` | ✅ | → `from` ?? `/home` |

Regla nueva en `AuthGuard`: **default = público**; existe un set de
`protectedPrefixes` (rutas que exigen sesión aun bajo un padre
público):

```dart
static const Set<String> protectedPrefixes = {
  '/home/cart/checkout',
  '/orders/',            // hijas del tab (detalle) — el root queda
  '/profile/data',
  '/profile/addresses',  // cubre /new y /edit por prefijo
  '/profile/password',
};
```

`/orders/` con slash final excluye el root (wall) y cubre `/orders/:id`.
`/profile/store` no está en el set → pública.

## Cambios por archivo

### Core / routing

| Archivo | Acción |
|---------|--------|
| `lib/core/routes/auth_guard.dart` | `protectedPrefixes` + nuevo set `authRoutes` (login/register/verify/forgot/reset — las que redirigen al entrar con sesión). `redirect(String location, {String? from})`: `!authed && isProtected → '/login?from=${Uri.encodeComponent(location)}'`; `authed && isAuthRoute → from ?? homeRoute`; resto → null. `defaultPublicRoutes` se reemplaza por este modelo (splash sigue siendo pública implícita — nunca protegida). Comentario de cabecera actualizado al nuevo modelo. |
| `lib/core/auth/auth_session.dart` | `extends ChangeNotifier` + `notifyListeners()` en `markAuthenticated`/`markLoggedOut` — los muros reaccionan al cambio de sesión EN EL SITIO (go(from) sobre la misma ruta puede no reconstruir el tab; y en §033 el logout hará reaparecer los muros solo). Singleton del locator — vive el proceso entero, sin dispose. |
| `lib/core/routes/app_router.dart` | `redirect` pasa `from: state.uri.queryParameters['from']` al guard. Sin cambios de rutas (las protegidas las filtra el guard, no la declaración). |
| `lib/core/screens/splash_screen.dart` | Tras `restoreSession` → `context.go(homeRoute)` **siempre** (éxito o invitado) — la carta es el destino default, no el login. `SplashCubit` sin cambios (sigue restaurando sesión cuando hay token válido). |
| `lib/core/widgets/auth_required_view.dart` | **nuevo** — muro de auth compartido (patrón pantalla de estado del estándar, familia `module_placeholder`/`catalog_states`): Icon 80px primary + título titleMedium + subtítulo bodyMedium α0.7 + `FilledButton` "Iniciar sesión" → `context.push('/login?from=<fromRoute>')` (push: el back nativo también regresa al tab, no solo el post-login) + `TextButton` "¿No tienes cuenta? Regístrate" → `/register?from=…`. Params: `icon`, `title`, `message`, `fromRoute`. |

### Pantallas

| Archivo | Acción |
|---------|--------|
| `lib/features/orders/presentation/screens/orders_screen.dart` | El contenido actual se envuelve en `ListenableBuilder(listenable: locator<AuthSession>())`: `isAuthenticated ? <lista real> : AuthRequiredView(icon: receipt_long_outlined, title: guestOrdersTitle, message: guestOrdersBody, fromRoute: AuthGuard.ordersRoute)` — el muro convive con SignatureStrip + título "Pedidos" (mismo esqueleto, solo cambia el área de contenido). La instancia de OrdersCubit NO se toca en modo invitado (no hay fetch). |
| `lib/features/profile/presentation/screens/profile_screen.dart` | Invitado (`!isAuthenticated`, mismo ListenableBuilder): ListView con título "Perfil" → **wall card** (straddle_card con la misma info del muro — icono person_outline + título + CTAs — pero como card dentro del scroll, no pantalla de estado: el tab sí muestra contenido real debajo) → sección "El negocio" (ProfileSectionLabel + El local → `/profile/store` + Soporte → diálogo — ambas filas idénticas a las de hoy). Sin: identidad, loyalty, "Mi cuenta", logout. Con sesión: el contenido actual intacto. Los BlocProvider de ProfileCubit/ProfileAddressesCubit solo se montan en la rama autenticada (el invitado no dispara cubits de datos de cliente). |
| `lib/features/auth/presentation/screens/login_screen.dart` | Éxito → `context.go(from ?? AuthGuard.homeRoute)` donde `from = GoRouterState.of(context).uri.queryParameters['from']` sanitizado (`startsWith('/')`). El link "Regístrate" propaga `?from=` si existe. |
| `lib/features/auth/presentation/screens/register_screen.dart` | Idem: éxito → `go(from)`; el link de retorno a login conserva el param si existe. |
| `lib/features/auth/presentation/screens/verify_email_screen.dart` | Idem en éxito (se llega acá desde login no-verificado — si vino `from` en el query de verify también se honra; propagación best-effort, no requerida por el flujo principal). |
| `lib/features/auth/presentation/screens/forgot_password_screen.dart` | Éxito (auto-login tras reset) → `go(from)` igual. |

### l10n (nuevas claves, ~6)

- `guestOrdersTitle`: "Inicia sesión para ver tus pedidos"
- `guestOrdersBody`: "Tus pedidos activos y el historial te esperan."
- `guestProfileTitle`: "Inicia sesión para ver tu perfil"
- `guestProfileBody`: "Tus datos, direcciones y puntos te esperan."
- `guestLoginCta`: reutilizar `loginButton` si el texto coincide; si no, clave nueva "Iniciar sesión"
- `guestRegisterCta`: reutilizar la clave del link "¿No tienes cuenta? Regístrate" del login si existe — el implementador verifica y reutiliza antes de crear.

### Backend (misma propuesta, commit aparte en pcalientes_backend)

| Archivo | Acción |
|---------|--------|
| `src/modules/catalog/presentation/controllers/catalog.controller.ts` | `@Public()` en `GET /catalog` + comentario actualizado (la carta es vitrina pública — decisión del usuario; el throttle global 100/min sigue aplicando). |
| `src/modules/store/presentation/controllers/store.controller.ts` | `@Public()` en `GET /store/config` + comentario (horarios/abierto también son info pública — el invitado ve "El local" sin cuenta). |
| `documentacion/api/catalog.md` + `store-config.md` | `Auth: ninguna` (antes "JWT requerido"). |
| e2e | Verificar que ningún spec aserte 401-sin-token en estos dos; **agregar** caso `200 sin Authorization` en ambos (la matriz de auth cambia — hay que fijarla). |

## Casos borde resueltos

- **Carrito de invitado → login → checkout**: CartCubit lazySingleton
  vive en el locator — el guest agrega, entra a checkout, el guard lo
  manda a login, vuelve con `from` → carrito intacto. (El carrito es de
  proceso; si cierra la app sin cuenta se pierde — comportamiento MVP
  ya existente, no cambia.)
- **Mismo-tab tras login**: `go('/orders')` sobre `/orders` puede no
  reconstruir — por eso el muro escucha `AuthSession` (ChangeNotifier):
  `markAuthenticated` dispara el swap muro→contenido aunque la ruta no
  cambie. Bonus §033: `markLoggedOut` hará reaparecer el muro en vivo.
- **Badge carrito / campana / chip del local**: funcionan para invitado
  sin cambios (local + endpoints ahora públicos).
- **`from` en el redirect del guard**: se encodea con
  `Uri.encodeComponent` — `/orders/abc?x=1` viaja íntegro.
- **Autenticado entrando a /login directo**: `from` ausente →
  `authenticatedRedirect` a `/home` (comportamiento de hoy).
- **Guest → checkout → login → correo no verificado**: login lleva a
  verify-email; `from` se propaga al query de verify best-effort.
- **Órdenes/profile cubits**: solo se instancian dentro de la rama
  autenticada — un invitado nunca gatilla `GET /orders` ni los mocks
  del perfil.

## Tests

- `auth_guard_test.dart` (reescritura de la matriz): invitado→home OK,
  invitado→checkout → `/login?from=…`, invitado→`/orders` OK,
  invitado→`/orders/x` → redirect, invitado→`/profile` OK,
  invitado→`/profile/data` → redirect, invitado→`/profile/store` OK,
  authed→`/login?from=/orders` → `/orders`, authed→`/login` → `/home`.
- `auth_session_test.dart`: `markAuthenticated`/`markLoggedOut` emiten
  `notifyListeners` (nuevo caso).
- Widget `orders_screen_test`/`profile_screen_test`: invitado ve el
  muro; perfil-invitado muestra "El negocio" (El local + Soporte) y NO
  muestra Mi cuenta/loyalty/logout; `markAuthenticated` con sesión fake
  → swap muro→contenido sin navegar (ListenableBuilder).
- `login_screen_test`: éxito con `?from=` → go(from); sin `from` →
  /home (regresión).
- Backend e2e: `GET /catalog` y `GET /store/config` → 200 sin
  Authorization; specs de controller con @Public si aplica.

## Verificación

- `flutter analyze` + `flutter test` completos; backend `npm run build`
  + `test` + `test:e2e`.
- Manual en emulador: sesión cerrada → carta completa + carrito +
  checkout rebota a login → login → vuelve a checkout con carrito
  intacto; tabs Pedidos/Perfil con muro; Perfil invitado con "El
  negocio"; tras login los muros se vuelven contenido sin reiniciar.

## Pendientes que esta propuesta NO cubre (quedan documentados)

- §031+ siguen: `/auth/me` real en Perfil, addresses reales, logout
  real, password-change (pendiente backend 013).
- La info de "El local" para invitado sigue siendo mock en la card (la
  integración de StoreInfo real es del ciclo de integración del
  perfil/local — el chip abierto/cerrado sí es real).
- Registro del patrón "muro de auth" en design-system.yaml tras la
  aprobación visual (componente nuevo `auth_required_view` + variante
  guest del Perfil).
