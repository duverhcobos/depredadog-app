import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:depredadog_app/core/layout/app_shell_layout.dart';
import 'package:depredadog_app/core/routes/auth_guard.dart';
import 'package:depredadog_app/core/screens/module_placeholder_screen.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
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
      MaterialApp.router(
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
    // Badge mock "2" del carrito (PROVISIONAL §016 — revisión visual).
    expect(find.text('2'), findsOneWidget);

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

  testWidgets('campana y carrito disparan AppToast "Disponible próximamente"', (
    tester,
  ) async {
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
    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pump();

    expect(calls, hasLength(2));
    expect(calls.first.method, 'showToast');
    expect(calls.first.arguments['msg'], 'Disponible próximamente');
    expect(calls.last.method, 'showToast');
    expect(calls.last.arguments['msg'], 'Disponible próximamente');

    // fluttertoast agenda un Future.delayed interno para reactivar su flag
    // isCurrentlyShowingToast — se deja expirar para no terminar con
    // timers pendientes.
    await tester.pump(const Duration(seconds: 2));
  });
}
