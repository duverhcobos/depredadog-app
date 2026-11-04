import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/home/presentation/data/catalog_mock.dart';
import '../../features/home/presentation/screens/category_products_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/product_detail_screen.dart';
import '../../l10n/app_localizations.dart';
import '../layout/app_shell_layout.dart';
import '../screens/module_placeholder_screen.dart';
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
      // El área autenticada vive dentro de un StatefulShellRoute (§016):
      // header + nav bar persistentes. Las pantallas reales de cada módulo
      // se declaran como HIJAS de su branch — NUNCA rutas raíz, porque eso
      // las sacaría del shell (navigation-routing).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShellLayout(shell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AuthGuard.homeRoute,
                pageBuilder: (context, state) =>
                    CustomTransitions.fade(state, const HomeScreen()),
                routes: [
                  GoRoute(
                    path: 'category/:categoryId',
                    pageBuilder: (context, state) => CustomTransitions.slideUp(
                      state,
                      CategoryProductsScreen(
                        category: CatalogCategoryX.fromSegment(
                          state.pathParameters['categoryId'] ?? '',
                        ),
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'product/:productId',
                        pageBuilder: (context, state) =>
                            CustomTransitions.slideUp(
                              state,
                              ProductDetailScreen(
                                item: catalogItemById(
                                  state.pathParameters['productId'] ?? '',
                                ),
                              ),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AuthGuard.ordersRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  state,
                  ModulePlaceholderScreen(
                    icon: Icons.receipt_long_rounded,
                    moduleLabel: AppLocalizations.of(context)!.shellTabOrders,
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AuthGuard.profileRoute,
                pageBuilder: (context, state) => CustomTransitions.fade(
                  state,
                  ModulePlaceholderScreen(
                    icon: Icons.person_rounded,
                    moduleLabel: AppLocalizations.of(context)!.shellTabProfile,
                  ),
                ),
              ),
            ],
          ),
        ],
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
      GoRoute(
        path: AuthGuard.forgotPasswordRoute,
        pageBuilder: (context, state) =>
            CustomTransitions.slideUp(state, const ForgotPasswordScreen()),
      ),
      // /reset-password se registra con su pantalla — el guard ya la
      // trata como pública. (El wizard de /forgot-password cubre los 3
      // pasos; /reset-password queda reservada para un deep link de
      // correo si algún día se usa — propuesta 011.)
    ],
  );
}
