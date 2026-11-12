/// Guardia de rutas — lógica de protección aislada del framework de routing
/// (regla 10 SOLID): recibe `isAuthenticated` y el `location` como String,
/// nunca GoRouterState, para que sea testeable y portable.
///
/// Modelo §031 (carta pública para invitados): el default es PÚBLICO —
/// la vitrina (home + catálogo + carrito) y los tabs con muro propio
/// (Pedidos, Perfil) se navegan sin sesión. La auth se exige por
/// PREFIJO solo donde la acción la requiere (`protectedPrefixes`) y el
/// redirect lleva `?from=` para volver al punto pedido tras el login.
/// Las `authRoutes` son las pantallas de entrada: con sesión ya dentro
/// no tienen sentido y devuelven a `from` o al home.
///
/// Las constantes de ruta completas viven AQUÍ (navigation-routing):
/// la UI navega siempre con estas constantes, nunca con strings sueltos.
class AuthGuard {
  const AuthGuard({required this._isAuthenticated});

  final bool Function() _isAuthenticated;

  // ---- Rutas (constantes públicas, siempre completas) ----
  static const String splashRoute = '/';
  static const String homeRoute = '/home';
  // Secciones del shell (§016): /orders y /profile son PÚBLICAS como
  // raíz desde §031 — el invitado ve un muro de auth DENTRO del tab
  // (AuthRequiredView), no un redirect.
  static const String ordersRoute = '/orders';
  static const String profileRoute = '/profile';
  // Direcciones del perfil (§030) — hijas de la rama profile dentro
  // del shell; exigen sesión vía protectedPrefixes. La edición viaja
  // como SavedAddress en `extra` (patrón cart/edit).
  static const String profileAddressesRoute = '/profile/addresses';
  static const String profileAddressNewRoute = '/profile/addresses/new';
  static const String profileAddressEditRoute = '/profile/addresses/edit';
  // Ampliación §030.1 — datos personales y cambio de contraseña son
  // protegidas por prefijo; la info del local queda pública (§031 —
  // horarios/abierto/dirección le sirven a cualquiera).
  static const String profileDataRoute = '/profile/data';
  static const String profileStoreRoute = '/profile/store';
  static const String profilePasswordRoute = '/profile/password';
  // Carrito — hijo de la rama home (dentro del shell, §020). Público:
  // el carrito del invitado es local (CartCubit de proceso).
  static const String cartRoute = '/home/cart';
  // Edición de la personalización de un ítem del carrito (§021) —
  // hija de cart; extra = CartItem.
  static const String cartEditRoute = '/home/cart/edit';
  // Checkout (§022) — hija de cart; redirect a /home/cart si el
  // carrito está vacío. PRIMERA ruta protegida del embudo (§031):
  // "Ir a pagar" sin sesión → /login?from=/home/cart/checkout.
  static const String checkoutRoute = '/home/cart/checkout';

  // Rutas de la feature auth — declaradas ya para que el guard las
  // conozca; se registran en app_router cuando existan sus pantallas.
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String verifyEmailRoute = '/verify-email';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String resetPasswordRoute = '/reset-password';

  /// Prefijos que exigen sesión aun bajo un padre público (§031).
  /// `/orders/` con slash final excluye el root (el muro vive en el
  /// tab) y cubre el detalle `/orders/:id`; `/profile/addresses`
  /// cubre /new y /edit por prefijo. `/profile/store` NO está —
  /// la info del negocio es pública.
  static const Set<String> protectedPrefixes = {
    '/home/cart/checkout',
    '/orders/',
    '/profile/data',
    '/profile/addresses',
    '/profile/password',
  };

  /// Pantallas de entrada a la cuenta — entrar CON sesión devuelve a
  /// `?from=` (si vino) o al home (match exacto: no tienen hijas).
  static const Set<String> authRoutes = {
    loginRoute,
    registerRoute,
    verifyEmailRoute,
    forgotPasswordRoute,
    resetPasswordRoute,
  };

  /// Sanitiza un `?from=` — solo se honran rutas internas (anti
  /// open-redirect): cualquier valor que no empiece por '/' cae a
  /// null, y '//…' también (scheme-relative — defensa en profundidad).
  /// Las pantallas de auth lo usan al leer su propio query.
  static String? sanitizeFrom(String? from) =>
      from != null && from.startsWith('/') && !from.startsWith('//')
      ? from
      : null;

  /// Devuelve la ruta de redirect o `null` si el acceso es válido.
  /// - Invitado pidiendo ruta protegida → `/login?from=<location>`
  ///   (el location viaja encodeado — solo el path: `matchedLocation`
  ///   no trae query, así que `/orders/abc?x=1` llega como `/orders/abc`).
  /// - Con sesión entrando a una ruta de auth → `from` sanitizado
  ///   o homeRoute (mismo default de hoy: /login sin from → /home).
  /// - Todo lo demás es público (splash incluido — nunca protegido).
  String? redirect(String location, {String? from}) {
    final authed = _isAuthenticated();

    if (!authed && protectedPrefixes.any(location.startsWith)) {
      return '$loginRoute?from=${Uri.encodeComponent(location)}';
    }
    if (authed && authRoutes.contains(location)) {
      return sanitizeFrom(from) ?? homeRoute;
    }
    return null;
  }
}
