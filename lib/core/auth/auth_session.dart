import '../../features/auth/domain/entities/user.dart';

/// SOLID (SRP): única verdad en memoria de "¿hay sesión activa en este
/// proceso?" + quién es el usuario. AuthGuard lee el flag de forma
/// síncrona (el guard no puede ser async); la fuente persistida son los
/// tokens en secure storage — esto es solo el reflejo en RAM.
class AuthSession {
  bool _isAuthenticated = false;
  User? _currentUser;

  bool get isAuthenticated => _isAuthenticated;

  /// Null hasta el primer login/verify/restore exitoso del proceso.
  User? get currentUser => _currentUser;

  void markAuthenticated(User user) {
    _isAuthenticated = true;
    _currentUser = user;
  }

  void markLoggedOut() {
    _isAuthenticated = false;
    _currentUser = null;
  }
}
