import 'package:flutter/foundation.dart';

import '../../features/auth/domain/entities/user.dart';

/// SOLID (SRP): única verdad en memoria de "¿hay sesión activa en este
/// proceso?" + quién es el usuario. AuthGuard lee el flag de forma
/// síncrona (el guard no puede ser async); la fuente persistida son los
/// tokens en secure storage — esto es solo el reflejo en RAM.
///
/// ChangeNotifier (§031): los muros de auth de los tabs (Pedidos,
/// Perfil) escuchan el flag para swappear muro↔contenido EN VIVO —
/// `go(from)` sobre la misma ruta puede no reconstruir el tab, y el
/// logout futuro (§033) hará reaparecer el muro sin navegar. Es
/// singleton del locator: vive el proceso entero, sin dispose.
class AuthSession extends ChangeNotifier {
  bool _isAuthenticated = false;
  User? _currentUser;

  bool get isAuthenticated => _isAuthenticated;

  /// Null hasta el primer login/verify/restore exitoso del proceso.
  User? get currentUser => _currentUser;

  void markAuthenticated(User user) {
    _isAuthenticated = true;
    _currentUser = user;
    notifyListeners();
  }

  void markLoggedOut() {
    _isAuthenticated = false;
    _currentUser = null;
    notifyListeners();
  }
}
