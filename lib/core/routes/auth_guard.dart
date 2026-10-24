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
  static const String welcomeRoute = '/welcome';
  static const String homeRoute = '/home';

  // Rutas de la feature auth (002) — declaradas ya para que el guard las
  // conozca; se registran en app_router cuando existan sus pantallas.
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String verifyEmailRoute = '/verify-email';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String resetPasswordRoute = '/reset-password';

  /// Rutas accesibles sin sesión.
  static const Set<String> defaultPublicRoutes = {
    splashRoute,
    welcomeRoute,
    loginRoute,
    registerRoute,
    verifyEmailRoute,
    forgotPasswordRoute,
    resetPasswordRoute,
  };

  /// A dónde mandar a un usuario sin sesión que pide una ruta protegida.
  static const String unauthenticatedRedirect = welcomeRoute;

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
