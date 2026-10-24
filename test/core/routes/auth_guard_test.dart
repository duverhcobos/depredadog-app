import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/routes/auth_guard.dart';

void main() {
  group('AuthGuard', () {
    test('sin sesión: ruta pública pasa, protegida redirige a /welcome', () {
      final guard = AuthGuard(isAuthenticated: () => false);

      expect(guard.redirect(AuthGuard.welcomeRoute), isNull);
      expect(guard.redirect(AuthGuard.loginRoute), isNull);
      expect(guard.redirect('/welcome/cualquier-hija'), isNull);
      expect(guard.redirect(AuthGuard.homeRoute), AuthGuard.welcomeRoute);
      expect(guard.redirect('/perfil'), AuthGuard.welcomeRoute);
    });

    test('con sesión: ruta de auth redirige a /home, protegida pasa', () {
      final guard = AuthGuard(isAuthenticated: () => true);

      expect(guard.redirect(AuthGuard.loginRoute), AuthGuard.homeRoute);
      expect(guard.redirect(AuthGuard.registerRoute), AuthGuard.homeRoute);
      expect(guard.redirect(AuthGuard.homeRoute), isNull);
    });

    test('con sesión: splash no redirige (decide la propia pantalla)', () {
      final guard = AuthGuard(isAuthenticated: () => true);
      expect(guard.redirect(AuthGuard.splashRoute), isNull);
    });

    test('publicRoutes inyectable por constructor (DIP)', () {
      final guard = AuthGuard(
        isAuthenticated: () => false,
        publicRoutes: {'/beta'},
      );
      expect(guard.redirect('/beta'), isNull);
      expect(guard.redirect(AuthGuard.welcomeRoute), AuthGuard.welcomeRoute);
    });
  });
}
