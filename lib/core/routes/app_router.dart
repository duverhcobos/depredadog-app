import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/cart/domain/entities/cart_item.dart';
import '../../features/cart/presentation/cubit/cart_cubit.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/checkout/presentation/cubit/checkout_cubit.dart';
import '../../features/checkout/presentation/screens/checkout_screen.dart';
import '../../features/home/presentation/cubit/catalog_cubit.dart';
import '../../features/home/presentation/screens/category_products_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/product_detail_screen.dart';
import '../../features/orders/domain/entities/customer_order.dart';
import '../../features/orders/presentation/cubit/orders_cubit.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/orders/presentation/screens/orders_screen.dart';
import '../../l10n/app_localizations.dart';
import '../di/setup_di.dart';
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
        // CatalogCubit sobre el shell (propuesta 019): las 3 pantallas
        // de catálogo (home, lista, detalle — rutas hijas dentro de la
        // branch) comparten la misma instancia y su caché. load() es
        // no-op si ya hay datos — el refresh real lo gatilla cada
        // pantalla al entrar. CartCubit (§020) comparte la posición:
        // una sola instancia sirve badge del header, pantalla de
        // carrito y el futuro checkout.
        builder: (context, state, navigationShell) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: locator<CatalogCubit>()..load()),
            BlocProvider.value(value: locator<CartCubit>()),
          ],
          child: AppShellLayout(shell: navigationShell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AuthGuard.homeRoute,
                pageBuilder: (context, state) =>
                    CustomTransitions.fade(state, const HomeScreen()),
                routes: [
                  GoRoute(
                    path: 'category/:categorySlug',
                    pageBuilder: (context, state) => CustomTransitions.slideUp(
                      state,
                      CategoryProductsScreen(
                        categorySlug:
                            state.pathParameters['categorySlug'] ?? '',
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'product/:productSlug',
                        pageBuilder: (context, state) =>
                            CustomTransitions.slideUp(
                              state,
                              ProductDetailScreen(
                                productSlug:
                                    state.pathParameters['productSlug'] ?? '',
                              ),
                            ),
                      ),
                    ],
                  ),
                  // Carrito (§020): hijo de la branch home — conserva
                  // header y nav bar del shell; misma transición
                  // slideUp del detalle.
                  GoRoute(
                    path: 'cart',
                    pageBuilder: (context, state) =>
                        CustomTransitions.slideUp(state, const CartScreen()),
                    routes: [
                      // Edición del ítem (§021) — extra = CartItem.
                      // Sin extra válido (deep link, estado
                      // restaurado) → back al carrito, no crash.
                      GoRoute(
                        path: 'edit',
                        redirect: (context, state) => state.extra is CartItem
                            ? null
                            : AuthGuard.cartRoute,
                        pageBuilder: (context, state) {
                          final item = state.extra as CartItem;
                          return CustomTransitions.slideUp(
                            state,
                            ProductDetailScreen(
                              productSlug: item.productSlug,
                              editingItem: item,
                            ),
                          );
                        },
                      ),
                      // Checkout (§022): hija de cart — conserva shell
                      // + nav; slideUp. CheckoutCubit factory por
                      // apertura (estado de pantalla). Carrito VACÍO →
                      // back al carrito: un deep link directo a
                      // confirmar sin ítems no tiene sentido.
                      GoRoute(
                        path: 'checkout',
                        redirect: (context, state) =>
                            locator<CartCubit>().state.isEmpty
                            ? AuthGuard.cartRoute
                            : null,
                        pageBuilder: (context, state) =>
                            CustomTransitions.slideUp(
                              state,
                              BlocProvider(
                                create: (_) =>
                                    locator<CheckoutCubit>()
                                      ..loadCheckoutData(),
                                child: const CheckoutScreen(),
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
                  BlocProvider.value(
                    // §027 — cada visita al tab recarga: el estado del
                    // pedido cambia server-side y el cliente entra a
                    // revisar si avanzó.
                    value: locator<OrdersCubit>()..loadOrders(),
                    child: const OrdersScreen(),
                  ),
                ),
                routes: [
                  // Detalle del pedido (§023 drill-down) — hija del
                  // tab, conserva shell + nav; extra = CustomerOrder.
                  // Deep link sin extra → al tab (igual que cart/edit).
                  GoRoute(
                    path: ':id',
                    redirect: (context, state) => state.extra is CustomerOrder
                        ? null
                        : AuthGuard.ordersRoute,
                    pageBuilder: (context, state) => CustomTransitions.slideUp(
                      state,
                      // Mismo OrdersCubit singleton del tab — el
                      // detalle cancela sobre la misma instancia.
                      // §027 — al abrir refresca el pedido: estado
                      // fresco + modifiers completos (el listado los
                      // omite, §015).
                      BlocProvider.value(
                        value: locator<OrdersCubit>()
                          ..refreshOrder((state.extra! as CustomerOrder).id),
                        child: OrderDetailScreen(
                          order: state.extra! as CustomerOrder,
                        ),
                      ),
                    ),
                  ),
                ],
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
