import 'package:go_router/go_router.dart';

import '../screens/splash_screen.dart';
import '../screens/welcome_screen.dart';
import 'auth_guard.dart';
import 'custom_transitions.dart';

/// Declaración de rutas. Las constantes viven en AuthGuard; los GoRoute
/// hijos usan segmentos RELATIVOS (navigation-routing).
/// NOTA: el GoRouter se construye una vez — tras tocar este archivo hace
/// falta hot RESTART, no reload.
class AppRouter {
  AppRouter({required this._guard});

  final AuthGuard _guard;

  late final GoRouter router = GoRouter(
    initialLocation: AuthGuard.splashRoute,
    redirect: (context, state) => _guard.redirect(state.matchedLocation),
    routes: [
      GoRoute(
        path: AuthGuard.splashRoute,
        pageBuilder: (context, state) =>
            CustomTransitions.fade(state, const SplashScreen()),
      ),
      GoRoute(
        path: AuthGuard.welcomeRoute,
        pageBuilder: (context, state) =>
            CustomTransitions.fade(state, const WelcomeScreen()),
      ),
      // /home es el destino autenticado — pantalla real llega con las
      // features; por ahora el guard bloquea el acceso sin sesión.
      // PROVISIONAL: placeholder hasta que 003-app-auth defina el shell.
      GoRoute(
        path: AuthGuard.homeRoute,
        pageBuilder: (context, state) =>
            CustomTransitions.fade(state, const WelcomeScreen()),
      ),
      // Las rutas /login, /register, /verify-email, /forgot-password y
      // /reset-password se registran en la propuesta 003-app-auth — el
      // guard ya las trata como públicas.
    ],
  );
}
