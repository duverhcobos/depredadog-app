/// Guardia de rutas — lógica de protección aislada del framework de routing
/// (regla 10 SOLID): recibe `isAuthenticated` y el `location` como String,
/// nunca GoRouterState, para que sea testeable y portable.
///
/// Las constantes de ruta completas viven AQUÍ (navigation-routing):
/// la UI navega siempre con estas constantes, nunca con strings sueltos.
class AuthGuard {
  const AuthGuard({required this._isAuthenticated, Set<String>? publicRoutes})
    : _publicRoutes = publicRoutes ?? defaultPublicRoutes;

  final bool Function() _isAuthenticated;
  final Set<String> _publicRoutes;

  // ---- Rutas (constantes públicas, siempre completas) ----
  static const String splashRoute = '/';
  static const String homeRoute = '/home';
  // Secciones del shell autenticado (§016) — protegidas por defecto:
  // no entran a defaultPublicRoutes.
  static const String ordersRoute = '/orders';
  static const String profileRoute = '/profile';
  // Direcciones del perfil (§030) — hijas de la rama profile dentro
  // del shell. La edición viaja como SavedAddress en `extra`
  // (patrón cart/edit).
  static const String profileAddressesRoute = '/profile/addresses';
  static const String profileAddressNewRoute = '/profile/addresses/new';
  static const String profileAddressEditRoute = '/profile/addresses/edit';
  // Ampliación §030.1 — datos personales, info del local y cambio de
  // contraseña: hijas directas de la rama profile dentro del shell.
  static const String profileDataRoute = '/profile/data';
  static const String profileStoreRoute = '/profile/store';
  static const String profilePasswordRoute = '/profile/password';
  // Carrito — hijo de la rama home (dentro del shell, §020).
  static const String cartRoute = '/home/cart';
  // Edición de la personalización de un ítem del carrito (§021) —
  // hija de cart; extra = CartItem.
  static const String cartEditRoute = '/home/cart/edit';
  // Checkout (§022) — hija de cart; redirect a /home/cart si el
  // carrito está vacío.
  static const String checkoutRoute = '/home/cart/checkout';

  // Rutas de la feature auth — declaradas ya para que el guard las
  // conozca; se registran en app_router cuando existan sus pantallas.
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String verifyEmailRoute = '/verify-email';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String resetPasswordRoute = '/reset-password';

  /// Rutas accesibles sin sesión.
  static const Set<String> defaultPublicRoutes = {
    splashRoute,
    loginRoute,
    registerRoute,
    verifyEmailRoute,
    forgotPasswordRoute,
    resetPasswordRoute,
  };

  /// A dónde mandar a un usuario sin sesión que pide una ruta protegida.
  static const String unauthenticatedRedirect = loginRoute;

  /// A dónde mandar a un usuario con sesión que pide una ruta de auth.
  static const String authenticatedRedirect = homeRoute;

  /// Devuelve la ruta de redirect o `null` si el acceso es válido.
  String? redirect(String location) {
    final isPublic = _publicRoutes.any(
      (r) => location == r || location.startsWith('$r/'),
    );
    final authed = _isAuthenticated();

    if (!authed && !isPublic) return unauthenticatedRedirect;
    if (authed && isPublic && location != splashRoute) {
      return authenticatedRedirect;
    }
    return null;
  }
}
