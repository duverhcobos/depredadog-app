/// SOLID (SRP): único flag en memoria de "¿hay sesión activa en este
/// proceso?". AuthGuard lo lee de forma síncrona (regla 10 SOLID — el
/// guard no puede ser async); la fuente de verdad persistida son los
/// tokens en secure storage (AuthLocalDataSource), esto es solo el
/// reflejo en RAM para no bloquear el redirect de go_router.
/// Restaurar la sesión leyendo el token guardado al abrir la app queda
/// diferido (ver pendientes/ — se resuelve junto con /auth/me).
class AuthSession {
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  void markAuthenticated() => _isAuthenticated = true;

  void markLoggedOut() => _isAuthenticated = false;
}
