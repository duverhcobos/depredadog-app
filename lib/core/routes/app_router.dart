import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../screens/home_placeholder_screen.dart';
import '../screens/splash_screen.dart';
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
      // /home es el destino autenticado — pantalla real llega con las
      // features; por ahora el guard bloquea el acceso sin sesión.
      // PROVISIONAL: placeholder hasta que exista el shell autenticado.
      GoRoute(
        path: AuthGuard.homeRoute,
        pageBuilder: (context, state) =>
            CustomTransitions.fade(state, const HomePlaceholderScreen()),
      ),
      GoRoute(
        path: AuthGuard.loginRoute,
        pageBuilder: (context, state) =>
            CustomTransitions.slideUp(state, const LoginScreen()),
      ),
      GoRoute(
        path: AuthGuard.registerRoute,
        pageBuilder: (context, state) =>
            CustomTransitions.slideUp(state, const RegisterScreen()),
      ),
      GoRoute(
        path: AuthGuard.verifyEmailRoute,
        pageBuilder: (context, state) => CustomTransitions.slideUp(
          state,
          VerifyEmailScreen(email: (state.extra as String?) ?? ''),
        ),
      ),
      // /forgot-password y /reset-password se registran con cada
      // pantalla — el guard ya las trata como públicas.
    ],
  );
}
