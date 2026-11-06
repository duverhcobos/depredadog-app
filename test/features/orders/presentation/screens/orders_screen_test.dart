import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';
import 'package:depredadog_app/features/orders/presentation/cubit/orders_cubit.dart';
import 'package:depredadog_app/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:depredadog_app/features/orders/presentation/screens/orders_screen.dart';
import 'package:depredadog_app/features/orders/presentation/widgets/active_order_card.dart';
import 'package:depredadog_app/features/orders/presentation/widgets/order_status_chip.dart';
import 'package:depredadog_app/features/orders/presentation/widgets/order_status_stepper.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  late OrdersCubit ordersCubit;
  late GoRouter router;

  OrdersCubit buildCubit({
    List<CustomerOrder>? seedActive,
    List<CustomerOrder>? seedHistory,
  }) => OrdersCubit(seedActive: seedActive, seedHistory: seedHistory);

  /// GoRouter mínimo (harness): /orders con la hija real :id
  /// (extra = CustomerOrder, igual que app_router) + stub /home para
  /// el CTA del estado vacío.
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/orders',
    routes: [
      GoRoute(
        path: '/orders',
        builder: (_, _) => const OrdersScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                OrderDetailScreen(order: state.extra! as CustomerOrder),
          ),
        ],
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Inicio')),
      ),
    ],
  );

  setUp(() {
    ordersCubit = buildCubit();
    router = buildRouter();
  });

  tearDown(() {
    ordersCubit.close();
    router.dispose();
  });

  /// Harness (misma mecánica del suite de checkout): cubit REAL con
  /// semillas + MaterialApp.router con l10n y el tema oscuro fijo.
  Future<void> pumpOrders(WidgetTester tester) => tester.pumpWidget(
    BlocProvider<OrdersCubit>.value(
      value: ordersCubit,
      child: MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: router,
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

  /// Detalle con CustomerOrder semilla + el cubit (revisor-ui §023:
  /// el detalle puede cancelar — necesita el provider como la ruta
  /// real). Sin GoRouter: el back y el pop post-cancel no se disparan.
  Future<void> pumpDetail(WidgetTester tester, CustomerOrder order) =>
      tester.pumpWidget(
        BlocProvider<OrdersCubit>.value(
          value: ordersCubit,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: OrderDetailScreen(order: order),
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

  /// Baja el ListView hasta que el finder aparezca — las secciones
  /// bajo el fold no están construidas (lazy) y find.text no las ve.
  /// `delta` negativo sube (targets que quedaron sobre el viewport).
  Future<void> scrollTo(
    WidgetTester tester,
    Finder finder, {
    double delta = 120,
  }) => tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );

  testWidgets('tab con los tres sabores activos + Historial', (tester) async {
    await pumpOrders(tester);
    await tester.pumpAndSettle();

    expect(find.text('Pedidos'), findsOneWidget);
    // Las straddle cards activas no llevan heading: un título pelado
    // caería mostaza sobre franja (revisor-estetico §023).

    // Delivery (ord-1) "En la plancha": solo el chip lo dice — el
    // stepper es gráfica pura (caption retirado, revisor-estetico) —
    // y los 2 dots previos con check → paso 3 activo.
    expect(find.text('Domicilio'), findsNWidgets(2)); // ord-1 y ord-6
    expect(find.text('En la plancha'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    expect(find.text('2× El Cachorro, 1× La Trampa'), findsOneWidget);
    expect(find.text('Casa — Casa blanca frente a la cancha'), findsOneWidget);
    expect(find.text('Con ubicación de Google'), findsOneWidget);
    expect(find.text('Nequi · pagado'), findsOneWidget);
    expect(find.text(r'$44.000'), findsOneWidget);

    // Pickup (ord-2) "Recibido" — único con "Cancelar pedido" (la
    // ventana es solo pending: el delivery NO lo muestra).
    await scrollTo(tester, find.text('Cancelar pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Recibido'), findsOneWidget);
    expect(
      find.text('Depredadog — Costado norte del parque principal'),
      findsOneWidget,
    );
    expect(find.text('Nequi · pago pendiente'), findsOneWidget);
    expect(find.text('Cancelar pedido'), findsOneWidget);

    // Delivery (ord-6) "Confirmado" pagando en efectivo — la única
    // card con "Pagas al recibir" (el local es prepago, §022c) y el
    // único paso Confirmed del stepper vivo.
    await scrollTo(tester, find.text('Pagas al recibir'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmado'), findsOneWidget);
    expect(find.text('1× Ave de Presa'), findsOneWidget);
    expect(
      find.text('Casa de mi mamá — Portón negro frente a la tienda'),
      findsOneWidget,
    );
    expect(find.text('Pagas al recibir'), findsOneWidget);
    expect(find.text(r'$18.000'), findsOneWidget);

    // Historial: filas-pill con fecha, conteo de ítems, total y chip
    // de estado ATENUADO (muted — terminal = evidencia, no acción).
    // Las fechas se buscan por prefijo: el año solo se muestra si NO
    // es el año en curso (revisor-ui §023 — hace el assert dependiente
    // del reloj de la máquina).
    await scrollTo(tester, find.textContaining('1 nov'));
    await tester.pumpAndSettle();
    expect(find.text('Historial'), findsOneWidget);
    expect(find.textContaining('7 nov'), findsOneWidget);
    expect(find.textContaining('4 nov'), findsOneWidget);
    expect(find.textContaining('1 nov'), findsOneWidget);
    expect(find.text('2 ítems'), findsNWidgets(2)); // ord-3 y ord-5
    expect(find.text('1 ítem'), findsOneWidget); // ord-4
    expect(
      find.byWidgetPredicate((w) => w is OrderStatusChip && w.muted),
      findsNWidgets(3),
    );
    expect(find.text('Entregado'), findsOneWidget);
    expect(find.text('Listo'), findsOneWidget);
    expect(find.text('Cancelado'), findsOneWidget);
  });

  testWidgets('cancelar en "Recibido": diálogo confirma → la card pasa a '
      'Historial como Cancelado', (tester) async {
    await pumpOrders(tester);
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Cancelar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar pedido'));
    await tester.pumpAndSettle();

    // Diálogo de confirmación — la cancelación no es un botón de
    // un solo tap (decisión del usuario §023).
    expect(find.text('¿Cancelar el pedido?'), findsOneWidget);
    expect(
      find.text('El local aún no lo confirma — puedes cancelar sin problema.'),
      findsOneWidget,
    );
    expect(find.text('No, dejarlo'), findsOneWidget);

    await tester.tap(find.text('Sí, cancelar'));
    await tester.pumpAndSettle();

    // El pickup salió de En curso y encabeza el historial como
    // cancelado.
    expect(ordersCubit.state.active, hasLength(2));
    expect(
      ordersCubit.state.active.map((o) => o.id),
      containsAll(<String>['ord-1', 'ord-6']),
    );
    expect(ordersCubit.state.history, hasLength(4));
    expect(ordersCubit.state.history.first.id, 'ord-2');
    expect(ordersCubit.state.history.first.status, OrderStatus.cancelled);
    // La CTA desapareció con la card (ya no hay pedido en pending).
    expect(find.text('Cancelar pedido'), findsNothing);
    expect(find.text('Local'), findsNothing);
  });

  testWidgets('cancelar: "No, dejarlo" conserva el pedido en curso', (
    tester,
  ) async {
    await pumpOrders(tester);
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Cancelar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No, dejarlo'));
    await tester.pumpAndSettle();

    expect(ordersCubit.state.active, hasLength(3));
    expect(ordersCubit.state.history, hasLength(3));
    expect(find.text('Cancelar pedido'), findsOneWidget);
  });

  testWidgets('tap en la card activa → push al detalle /orders/ord-1', (
    tester,
  ) async {
    await pumpOrders(tester);
    await tester.pumpAndSettle();

    // El resumen de ítems es único de ord-1 — "Domicilio" lo llevan
    // también la card ord-6 y el detalle.
    await tester.tap(
      find.ancestor(
        of: find.text('2× El Cachorro, 1× La Trampa'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailScreen), findsOneWidget);
    expect(find.text('Detalle del pedido'), findsOneWidget);
    expect(find.text('Casa blanca frente a la cancha'), findsOneWidget);
    // Destino: la hija :id con extra = la orden tocada (drill-down
    // que conserva el tab detrás). push() agrega un match imperativo
    // sobre /orders — el último match lleva la location completa.
    expect(
      router.routerDelegate.currentConfiguration.matches.last.matchedLocation,
      '/orders/ord-1',
    );
  });

  testWidgets('vacío → ícono + copy + CTA "Ver el menú" a /home', (
    tester,
  ) async {
    await ordersCubit.close();
    ordersCubit = buildCubit(seedActive: const [], seedHistory: const []);
    await pumpOrders(tester);
    await tester.pumpAndSettle();

    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Aún no has pedido'), findsOneWidget);
    expect(find.text('Tu próximo antojo empieza en el menú'), findsOneWidget);
    expect(find.byType(ActiveOrderCard), findsNothing);
    expect(find.text('Historial'), findsNothing);
    expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Ver el menú'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/home');
    expect(find.text('Inicio'), findsOneWidget);
  });

  group('detalle del pedido (CustomerOrder semilla)', () {
    testWidgets('delivery "En la plancha": secciones, ítems, referencia '
        'y totales con "Gratis" primary', (tester) async {
      await pumpDetail(tester, kMockOrderDelivery);
      await tester.pumpAndSettle();

      // Estado: "Pedido el …" (placedAt prefijado, no la fecha del
      // cambio — revisor-ui §023; el año depende del reloj) + chip +
      // stepper (no cancelado).
      expect(find.text('Detalle del pedido'), findsOneWidget);
      expect(find.text('Estado'), findsOneWidget);
      expect(find.textContaining('Pedido el 8 nov'), findsOneWidget);
      expect(find.byType(OrderStatusStepper), findsOneWidget);
      expect(find.text('En la plancha'), findsOneWidget);

      // Tu pedido: ítems + lineTotals + totales. La personalización
      // vive tras el chip "Detalle" por secciones — el MISMO idioma
      // del carrito (decisión del usuario: verificar qué quedó en
      // cada perro).
      await scrollTo(tester, find.text('Total'));
      await tester.pumpAndSettle();
      expect(find.text('Tu pedido'), findsOneWidget);
      expect(find.text('2× El Cachorro'), findsOneWidget);
      expect(find.text('1× La Trampa'), findsOneWidget);
      expect(find.text(r'$28.000'), findsOneWidget);
      expect(find.text(r'$16.000'), findsOneWidget);
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text(r'$44.000'), findsNWidgets(2));

      // Chip "Detalle" de El Cachorro → secciones Ingredientes /
      // Se le quitó / Adicionales / Toppings / Salsas.
      await tester.tap(find.text('Detalle').first);
      await tester.pumpAndSettle();
      expect(find.text('Ingredientes'), findsOneWidget);
      expect(find.text('Pan brioche'), findsWidgets);
      expect(find.text('Se le quitó'), findsOneWidget);
      expect(find.text('Queso mozzarella'), findsOneWidget);
      expect(find.text('Adicionales'), findsOneWidget);
      expect(find.textContaining('Salami'), findsOneWidget);
      expect(find.textContaining(r'+$3.000'), findsOneWidget);
      expect(find.text('Toppings'), findsOneWidget);
      expect(find.text('Maíz tierno'), findsOneWidget);
      expect(find.text('Salsas'), findsOneWidget);
      expect(find.text('Salsa rosada'), findsOneWidget);
      // "Domicilio: Gratis" con el valor en primary (domicilio gratis
      // — mismo idioma del resumen del checkout).
      expect(find.text('Gratis'), findsOneWidget);
      final gratis = tester.widget<Text>(find.text('Gratis'));
      expect(gratis.style?.color, AppTheme.dark().colorScheme.primary);

      // Entrega y pago: etiqueta, referencia, barrio, pin y Nequi.
      await scrollTo(tester, find.text('Entrega y pago'));
      await tester.pumpAndSettle();
      expect(find.text('Casa'), findsOneWidget);
      expect(find.text('Casa blanca frente a la cancha'), findsOneWidget);
      expect(find.text('Vereda El Carmen'), findsOneWidget);
      expect(find.text('Con ubicación de Google'), findsOneWidget);
      expect(find.text('Nequi · pagado'), findsWidgets);

      // Observación (solo existe porque el pedido la tiene).
      await scrollTo(tester, find.text('Observación'));
      await tester.pumpAndSettle();
      expect(find.text('Observación'), findsOneWidget);
      expect(find.text('pago con billete de 50, traer cambio'), findsOneWidget);
    });

    testWidgets('pickup "done": paso final se lee "Listo — ya puedes '
        'pasar" y no hay fila de domicilio', (tester) async {
      final pickupDone = kMockHistory.firstWhere((o) => o.id == 'ord-4');
      await pumpDetail(tester, pickupDone);
      await tester.pumpAndSettle();

      expect(find.text('Listo'), findsOneWidget); // chip
      // El progreso vive en el Semantics del stepper como "Paso N de
      // 4: …" (caption visible retirado — el chip ya nombra el estado).
      expect(
        find.bySemanticsLabel('Paso 4 de 4: Listo — ya puedes pasar'),
        findsOneWidget,
      );
      expect(find.text('Entregado'), findsNothing);

      // Servicio local: sin fila Domicilio ni "Gratis" en totales.
      await scrollTo(tester, find.text('Total'));
      await tester.pumpAndSettle();
      expect(find.text('Domicilio'), findsNothing);
      expect(find.text('Gratis'), findsNothing);
      expect(find.text(r'$14.000'), findsWidgets);

      await scrollTo(tester, find.text('Entrega y pago'));
      await tester.pumpAndSettle();
      expect(
        find.text('Depredadog — Costado norte del parque principal'),
        findsOneWidget,
      );
    });

    testWidgets('cancelado: chip + razón SIN stepper ni observación', (
      tester,
    ) async {
      final cancelled = kMockHistory.firstWhere((o) => o.id == 'ord-5');
      await pumpDetail(tester, cancelled);
      await tester.pumpAndSettle();

      expect(find.text('Cancelado'), findsOneWidget);
      expect(find.text('Cancelado por el cliente'), findsOneWidget);
      // El stepper no aplica a terminales cancelados (§023).
      expect(find.byType(OrderStatusStepper), findsNothing);
      // Sin nota del cliente → la sección Observación no existe.
      expect(find.text('Observación'), findsNothing);

      await scrollTo(tester, find.text('Entrega y pago'));
      await tester.pumpAndSettle();
      expect(find.text('Frente a la farmacia'), findsOneWidget);
      // Terminal → el pago contra entrega habla en pasado ("Pagaste",
      // no "Pagas" — revisor-ui §023).
      expect(find.text('Pagaste al recibir'), findsOneWidget);
    });

    testWidgets('cancelar desde el detalle vuelve al tab con el pedido '
        'migrado al historial', (tester) async {
      await pumpOrders(tester);
      await tester.pumpAndSettle();

      // Tap en la card pickup (ord-2 "Recibido") → detalle.
      await scrollTo(tester, find.text('Local'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(of: find.text('Local'), matching: find.byType(InkWell)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(find.text('Cancelar pedido'), findsOneWidget);

      await tester.tap(find.text('Cancelar pedido'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      // Pop al tab; ord-2 migra al historial como cancelado (misma
      // instancia singleton — revisor-ui §023).
      expect(find.byType(OrderDetailScreen), findsNothing);
      expect(ordersCubit.state.active, hasLength(2));
      expect(ordersCubit.state.history.first.id, 'ord-2');
      expect(ordersCubit.state.history.first.status, OrderStatus.cancelled);
    });
  });
}
