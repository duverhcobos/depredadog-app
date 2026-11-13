import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/routes/auth_guard.dart';

void main() {
  String loginFrom(String location) =>
      '${AuthGuard.loginRoute}?from=${Uri.encodeComponent(location)}';

  group('AuthGuard (§031 — default público + prefijos protegidos)', () {
    test('invitado: la vitrina completa pasa — splash, carta, carrito', () {
      final guard = AuthGuard(
        isAuthenticated: () => false,
        isAdmin: () => false,
      );

      expect(guard.redirect(AuthGuard.splashRoute), isNull);
      expect(guard.redirect(AuthGuard.homeRoute), isNull);
      expect(guard.redirect('/home/category/perros'), isNull);
      expect(guard.redirect('/home/category/perros/product/cachorro'), isNull);
      expect(guard.redirect(AuthGuard.cartRoute), isNull);
      expect(guard.redirect(AuthGuard.cartEditRoute), isNull);
    });

    test('invitado: los tabs con muro y las pantallas de auth pasan', () {
      final guard = AuthGuard(
        isAuthenticated: () => false,
        isAdmin: () => false,
      );

      // Los roots de Pedidos/Perfil NO redirigen — el muro de auth
      // vive DENTRO del tab (decisión del usuario §031).
      expect(guard.redirect(AuthGuard.ordersRoute), isNull);
      expect(guard.redirect(AuthGuard.profileRoute), isNull);
      // La info del negocio es pública — no está en protectedPrefixes.
      expect(guard.redirect(AuthGuard.profileStoreRoute), isNull);
      expect(guard.redirect(AuthGuard.loginRoute), isNull);
      expect(guard.redirect(AuthGuard.registerRoute), isNull);
      expect(guard.redirect(AuthGuard.verifyEmailRoute), isNull);
      expect(guard.redirect(AuthGuard.forgotPasswordRoute), isNull);
      expect(guard.redirect(AuthGuard.resetPasswordRoute), isNull);
    });

    test('invitado: prefijos protegidos → /login?from=<ruta encodeada>', () {
      final guard = AuthGuard(
        isAuthenticated: () => false,
        isAdmin: () => false,
      );

      // Primera ruta protegida del embudo: "Ir a pagar" sin sesión.
      expect(
        guard.redirect(AuthGuard.checkoutRoute),
        loginFrom(AuthGuard.checkoutRoute),
      );
      // '/orders/' con slash final cubre el detalle pero no el root.
      expect(guard.redirect('/orders/abc'), loginFrom('/orders/abc'));
      expect(guard.redirect('/orders/abc?x=1'), loginFrom('/orders/abc?x=1'));
      expect(
        guard.redirect(AuthGuard.profileDataRoute),
        loginFrom(AuthGuard.profileDataRoute),
      );
      // '/profile/addresses' cubre /new y /edit por prefijo.
      expect(
        guard.redirect(AuthGuard.profileAddressesRoute),
        loginFrom(AuthGuard.profileAddressesRoute),
      );
      expect(
        guard.redirect(AuthGuard.profileAddressNewRoute),
        loginFrom(AuthGuard.profileAddressNewRoute),
      );
      expect(
        guard.redirect(AuthGuard.profileAddressEditRoute),
        loginFrom(AuthGuard.profileAddressEditRoute),
      );
      expect(
        guard.redirect(AuthGuard.profilePasswordRoute),
        loginFrom(AuthGuard.profilePasswordRoute),
      );
    });

    test('con sesión: protegidas y públicas pasan, rutas de auth → /home', () {
      final guard = AuthGuard(
        isAuthenticated: () => true,
        isAdmin: () => false,
      );

      expect(guard.redirect(AuthGuard.checkoutRoute), isNull);
      expect(guard.redirect('/orders/abc'), isNull);
      expect(guard.redirect(AuthGuard.profileDataRoute), isNull);
      expect(guard.redirect(AuthGuard.homeRoute), isNull);
      expect(guard.redirect(AuthGuard.ordersRoute), isNull);

      // Entrar a una pantalla de auth ya con sesión no tiene sentido.
      expect(guard.redirect(AuthGuard.loginRoute), AuthGuard.homeRoute);
      expect(guard.redirect(AuthGuard.registerRoute), AuthGuard.homeRoute);
      expect(guard.redirect(AuthGuard.verifyEmailRoute), AuthGuard.homeRoute);
      expect(
        guard.redirect(AuthGuard.forgotPasswordRoute),
        AuthGuard.homeRoute,
      );
      expect(guard.redirect(AuthGuard.resetPasswordRoute), AuthGuard.homeRoute);
    });

    test('con sesión en ruta de auth: ?from= interno se honra', () {
      final guard = AuthGuard(
        isAuthenticated: () => true,
        isAdmin: () => false,
      );

      expect(guard.redirect(AuthGuard.loginRoute, from: '/orders'), '/orders');
      expect(
        guard.redirect(AuthGuard.registerRoute, from: '/home/cart/checkout'),
        '/home/cart/checkout',
      );
      expect(
        guard.redirect(AuthGuard.loginRoute, from: '/orders/abc?x=1'),
        '/orders/abc?x=1',
      );
    });

    test('con sesión en ruta de auth: ?from= externo o relativo se '
        'descarta → /home (anti open-redirect)', () {
      final guard = AuthGuard(
        isAuthenticated: () => true,
        isAdmin: () => false,
      );

      expect(
        guard.redirect(AuthGuard.loginRoute, from: 'https://evil.com'),
        AuthGuard.homeRoute,
      );
      expect(
        guard.redirect(AuthGuard.loginRoute, from: 'orders'),
        AuthGuard.homeRoute,
      );
      expect(
        guard.redirect(AuthGuard.loginRoute, from: ''),
        AuthGuard.homeRoute,
      );
    });

    test('con sesión: splash no redirige (decide la propia pantalla)', () {
      final guard = AuthGuard(
        isAuthenticated: () => true,
        isAdmin: () => false,
      );
      expect(guard.redirect(AuthGuard.splashRoute), isNull);
    });
  });

  group('AuthGuard (§034 — prefijos admin exigen sesión Y rol)', () {
    test('invitado: /admin y sus hijas → /login?from=<ruta encodeada>', () {
      final guard = AuthGuard(
        isAuthenticated: () => false,
        isAdmin: () => false,
      );

      expect(
        guard.redirect(AuthGuard.adminRoute),
        loginFrom(AuthGuard.adminRoute),
      );
      // El deep link a una hija de la cola también aterriza tras el
      // login (mismo mecanismo sanitizeFrom de los protegidos).
      expect(
        guard.redirect('/admin/orders/abc'),
        loginFrom('/admin/orders/abc'),
      );
    });

    test('cliente con sesión sin rol admin: /admin → /home', () {
      final guard = AuthGuard(
        isAuthenticated: () => true,
        isAdmin: () => false,
      );

      expect(guard.redirect(AuthGuard.adminRoute), AuthGuard.homeRoute);
      expect(guard.redirect('/admin/orders/abc'), AuthGuard.homeRoute);
      // El resto de la app del cliente no se toca.
      expect(guard.redirect(AuthGuard.homeRoute), isNull);
      expect(guard.redirect('/orders/abc'), isNull);
    });

    test('admin con sesión: /admin y sus hijas pasan', () {
      final guard = AuthGuard(isAuthenticated: () => true, isAdmin: () => true);

      expect(guard.redirect(AuthGuard.adminRoute), isNull);
      expect(guard.redirect('/admin/orders/abc'), isNull);
    });
  });
}
