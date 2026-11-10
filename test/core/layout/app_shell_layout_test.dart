import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/layout/app_shell_layout.dart';
import 'package:depredadog_app/core/routes/auth_guard.dart';
import 'package:depredadog_app/core/screens/module_placeholder_screen.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/core/widgets/store_status_chip.dart';
import 'package:depredadog_app/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:depredadog_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:depredadog_app/features/store/domain/entities/store_open_state.dart';
import 'package:depredadog_app/features/store/presentation/cubit/store_status_cubit.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

class MockStoreStatusCubit extends MockCubit<StoreOpenState>
    implements StoreStatusCubit {}

void main() {
  // CartCubit real (§020): el badge del header lee sus unidades con
  // context.select — los métodos síncronos no necesitan mock.
  late CartCubit cartCubit;
  // §029 — el chip del header ahora es real: lo alimenta el
  // StoreStatusCubit del shell (mock — default abierto).
  late MockStoreStatusCubit storeCubit;

  void stubStoreState(StoreOpenState state) => whenListen(
    storeCubit,
    const Stream<StoreOpenState>.empty(),
    initialState: state,
  );

  setUp(() {
    cartCubit = CartCubit();
    storeCubit = MockStoreStatusCubit();
    when(() => storeCubit.refresh()).thenAnswer((_) async {});
    stubStoreState(StoreOpenState.open);
  });
  tearDown(() {
    cartCubit.close();
    storeCubit.close();
  });

  GoRouter buildShellRouter() {
    // Misma estructura que app_router (§016) pero sin AuthGuard — la
    // protección de rutas ya se ejerce en test/core/routes/auth_guard_test.
    return GoRouter(
      initialLocation: AuthGuard.homeRoute,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShellLayout(shell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AuthGuard.homeRoute,
                  builder: (context, state) => ModulePlaceholderScreen(
                    icon: Icons.home_rounded,
                    moduleLabel: AppLocalizations.of(context)!.shellTabHome,
                  ),
                  routes: [
                    // Carrito real (§020) — el tap del icono del
                    // header navega acá con push() (preserva el
                    // stack del detalle, revisor-ui §020).
                    GoRoute(
                      path: 'cart',
                      builder: (context, state) => const CartScreen(),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AuthGuard.ordersRoute,
                  builder: (context, state) => ModulePlaceholderScreen(
                    icon: Icons.receipt_long_rounded,
                    moduleLabel: AppLocalizations.of(context)!.shellTabOrders,
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AuthGuard.profileRoute,
                  builder: (context, state) => ModulePlaceholderScreen(
                    icon: Icons.person_rounded,
                    moduleLabel: AppLocalizations.of(context)!.shellTabProfile,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> pumpShell(WidgetTester tester) {
    return tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<CartCubit>.value(value: cartCubit),
          BlocProvider<StoreStatusCubit>.value(value: storeCubit),
        ],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: buildShellRouter(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
        ),
      ),
    );
  }

  testWidgets('renderiza header (imagotipo + acciones) y nav bar de 3 tabs', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.pumpAndSettle();

    // Header: imagotipo de marca + 2 IconButtons con sus tooltips.
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(IconButton), findsNWidgets(2));
    expect(find.byTooltip('Notificaciones'), findsOneWidget);
    expect(find.byTooltip('Carrito'), findsOneWidget);
    // Badge real del carrito (§020): vacío → sin etiqueta visible.
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    // Con una unidad en el cubit el badge muestra el conteo.
    cartCubit.addItem(
      productId: 'p-cachorro',
      productSlug: 'cachorro',
      productName: 'El Cachorro',
      unitBase: 14000,
      modifiers: const [],
    );
    // El emit llega al select por el stream del bloc (microtarea) —
    // pumpAndSettle garantiza el rebuild del header.
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    // NavigationBar M3 con los 3 destinos del shell.
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    final nav = find.byType(NavigationBar);
    expect(find.descendant(of: nav, matching: find.text('Inicio')), findsOne);
    expect(find.descendant(of: nav, matching: find.text('Pedidos')), findsOne);
    expect(find.descendant(of: nav, matching: find.text('Perfil')), findsOne);

    // Branch inicial: /home — placeholder con patrón de estado
    // (icono + título del módulo + "Disponible próximamente").
    expect(
      find.descendant(
        of: find.byType(ModulePlaceholderScreen),
        matching: find.text('Inicio'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ModulePlaceholderScreen),
        matching: find.text('Disponible próximamente'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ModulePlaceholderScreen),
        matching: find.byIcon(Icons.home_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('cambiar de tab muestra su placeholder y marca el destino', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pedidos'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(ModulePlaceholderScreen),
        matching: find.text('Pedidos'),
      ),
      findsOneWidget,
    );
    // El branch de Inicio queda offstage (indexedStack conserva estado).
    expect(
      find.descendant(
        of: find.byType(ModulePlaceholderScreen),
        matching: find.text('Inicio'),
      ),
      findsNothing,
    );
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(ModulePlaceholderScreen),
        matching: find.text('Inicio'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ModulePlaceholderScreen),
        matching: find.text('Pedidos'),
      ),
      findsNothing,
    );
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets(
    'campana dispara AppToast "Disponible próximamente"; carrito navega a /home/cart',
    (tester) async {
      // fluttertoast no pinta en el árbol de widgets — va por MethodChannel;
      // se intercepta el canal y se verifica el mensaje real (mismo patrón
      // que login_screen_test).
      const channel = MethodChannel('PonnamKarthik/fluttertoast');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );

      await pumpShell(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pump();

      // El carrito ya no es toast (§020): navega a /home/cart DENTRO
      // del shell — la NavBar y el header se conservan.
      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.first.method, 'showToast');
      expect(calls.first.arguments['msg'], 'Disponible próximamente');
      expect(find.text('Tu carrito'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      // fluttertoast agenda un Future.delayed interno para reactivar su flag
      // isCurrentlyShowingToast — se deja expirar para no terminar con
      // timers pendientes.
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('chip del header: open → "Abierto" (§029 — el mock '
      'isOpen:true quedó atrás)', (tester) async {
    stubStoreState(StoreOpenState.open);
    await pumpShell(tester);
    await tester.pumpAndSettle();

    expect(find.byType(StoreStatusChip), findsOneWidget);
    expect(find.text('Abierto'), findsOneWidget);
    expect(find.text('Cerrado'), findsNothing);
  });

  testWidgets('chip del header: closed → "Cerrado" (§029)', (tester) async {
    stubStoreState(StoreOpenState.closed);
    await pumpShell(tester);
    await tester.pumpAndSettle();

    expect(find.byType(StoreStatusChip), findsOneWidget);
    expect(find.text('Cerrado'), findsOneWidget);
    expect(find.text('Abierto'), findsNothing);
  });

  testWidgets('chip del header: unknown → oculto (§029 — mejor no '
      'mostrar que mentir)', (tester) async {
    stubStoreState(StoreOpenState.unknown);
    await pumpShell(tester);
    await tester.pumpAndSettle();

    expect(find.byType(StoreStatusChip), findsNothing);
    expect(find.text('Abierto'), findsNothing);
    expect(find.text('Cerrado'), findsNothing);
  });
}
