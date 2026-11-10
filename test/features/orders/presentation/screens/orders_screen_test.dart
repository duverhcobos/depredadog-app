import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';
import 'package:depredadog_app/features/orders/domain/failures/orders_failure.dart';
import 'package:depredadog_app/features/orders/domain/repositories/i_orders_repository.dart';
import 'package:depredadog_app/features/orders/domain/use_cases/cancel_order_use_case.dart';
import 'package:depredadog_app/features/orders/domain/use_cases/get_order_detail_use_case.dart';
import 'package:depredadog_app/features/orders/domain/use_cases/load_more_history_use_case.dart';
import 'package:depredadog_app/features/orders/domain/use_cases/load_orders_use_case.dart';
import 'package:depredadog_app/features/orders/presentation/cubit/orders_cubit.dart';
import 'package:depredadog_app/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:depredadog_app/features/orders/presentation/screens/orders_screen.dart';
import 'package:depredadog_app/features/orders/presentation/widgets/active_order_card.dart';
import 'package:depredadog_app/features/orders/presentation/widgets/order_status_chip.dart';
import 'package:depredadog_app/features/orders/presentation/widgets/order_status_stepper.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

class MockLoadOrders extends Mock implements LoadOrdersUseCase {}

class MockLoadMoreHistory extends Mock implements LoadMoreHistoryUseCase {}

class MockGetOrderDetail extends Mock implements GetOrderDetailUseCase {}

class MockCancelOrder extends Mock implements CancelOrderUseCase {}

/// Fixtures del tab (§023 — los mocks del cubit murieron en §027;
/// acá viven solo para el harness de presentación).

/// Domicilio "En la plancha" — con pin adjunto y Nequi pago.
final _orderDelivery = CustomerOrder(
  id: 'ord-1',
  serviceType: OrderServiceType.delivery,
  status: OrderStatus.preparing,
  items: const [
    OrderItem(
      productId: 'p-cachorro',
      productSlug: 'cachorro',
      name: 'El Cachorro',
      quantity: 2,
      unitPrice: 14000,
      includedNames: [
        'Pan brioche',
        'Salchicha americana',
        'Papas a la francesa',
        'Cebolla grillada',
      ],
      modifiers: [
        CartModifier(
          optionId: 'opt-mozz',
          optionName: 'Queso mozzarella',
          action: CartModifierAction.removed,
          priceDelta: 0,
          group: CartModifierGroup.ingredient,
        ),
        CartModifier(
          optionId: 'opt-salami',
          optionName: 'Salami',
          action: CartModifierAction.added,
          priceDelta: 3000,
          group: CartModifierGroup.extra,
        ),
        CartModifier(
          optionId: 'opt-maiz',
          optionName: 'Maíz tierno',
          action: CartModifierAction.added,
          priceDelta: 0,
          group: CartModifierGroup.topping,
        ),
        CartModifier(
          optionId: 'opt-rosada',
          optionName: 'Salsa rosada',
          action: CartModifierAction.added,
          priceDelta: 0,
          group: CartModifierGroup.sauce,
        ),
      ],
    ),
    OrderItem(
      productId: 'p-trampa',
      productSlug: 'trampa',
      name: 'La Trampa',
      quantity: 1,
      unitPrice: 16000,
      includedNames: [
        'Pan brioche',
        'Salchicha americana',
        'Tocineta',
        'Huevo de codorniz',
      ],
    ),
  ],
  paymentMethod: OrderPaymentMethod.nequi,
  paymentStatus: OrderPaymentStatus.paid,
  subtotal: 44000,
  deliveryFee: 0,
  placedAt: DateTime(2026, 11, 8, 12, 40),
  statusChangedAt: DateTime(2026, 11, 8, 12, 52),
  addressLabel: 'Casa',
  landmark: 'Casa blanca frente a la cancha',
  neighborhood: 'Vereda El Carmen',
  hasLocationPin: true,
  contactPhone: '3001234567',
  note: 'pago con billete de 50, traer cambio',
);

/// Local "Recibido" — muestra el botón cancelar (única ventana).
final _orderPickup = CustomerOrder(
  id: 'ord-2',
  serviceType: OrderServiceType.pickup,
  status: OrderStatus.received,
  items: const [
    OrderItem(
      productId: 'p-depredador',
      productSlug: 'depredador',
      name: 'El Depredador',
      quantity: 1,
      unitPrice: 25000,
      includedNames: [
        'Pan brioche',
        'Salchicha americana',
        'Tocineta',
        'Champiñones',
      ],
      modifiers: [
        CartModifier(
          optionId: 'opt-tocineta',
          optionName: 'Tocineta crocante',
          action: CartModifierAction.added,
          priceDelta: 4000,
          group: CartModifierGroup.extra,
        ),
      ],
    ),
  ],
  paymentMethod: OrderPaymentMethod.nequi,
  paymentStatus: OrderPaymentStatus.pending,
  subtotal: 25000,
  deliveryFee: 0,
  placedAt: DateTime(2026, 11, 8, 13, 10),
  statusChangedAt: DateTime(2026, 11, 8, 13, 10),
  storeReference: 'Depredadog — Costado norte del parque principal',
);

/// Domicilio "Confirmado" pagando en efectivo contra entrega.
final _orderDeliveryCash = CustomerOrder(
  id: 'ord-6',
  serviceType: OrderServiceType.delivery,
  status: OrderStatus.confirmed,
  items: const [
    OrderItem(
      productId: 'p-ave',
      productSlug: 'ave-de-presa',
      name: 'Ave de Presa',
      quantity: 1,
      unitPrice: 18000,
      includedNames: ['Pan brioche', 'Pechuga apanada', 'Queso', 'Lechuga'],
      modifiers: [
        CartModifier(
          optionId: 'opt-salsa-casa',
          optionName: 'Salsa de la casa',
          action: CartModifierAction.removed,
          priceDelta: 0,
          group: CartModifierGroup.ingredient,
        ),
      ],
    ),
  ],
  paymentMethod: OrderPaymentMethod.onDelivery,
  paymentStatus: OrderPaymentStatus.pending,
  subtotal: 18000,
  deliveryFee: 0,
  placedAt: DateTime(2026, 11, 8, 13, 45),
  statusChangedAt: DateTime(2026, 11, 8, 13, 50),
  addressLabel: 'Casa de mi mamá',
  landmark: 'Portón negro frente a la tienda',
  neighborhood: 'Vereda El Carmen',
  contactPhone: '3109876543',
  note: 'Traer cambio de 20',
);

final _history = <CustomerOrder>[
  CustomerOrder(
    id: 'ord-3',
    serviceType: OrderServiceType.delivery,
    status: OrderStatus.done,
    items: const [
      OrderItem(
        productId: 'p-coyote',
        productSlug: 'coyote',
        name: 'El Coyote',
        quantity: 2,
        unitPrice: 18000,
        includedNames: [
          'Pan brioche',
          'Salchicha americana',
          'Queso mozzarella',
        ],
        modifiers: [
          CartModifier(
            optionId: 'opt-huevo',
            optionName: 'Huevo de codorniz',
            action: CartModifierAction.removed,
            priceDelta: 0,
            group: CartModifierGroup.ingredient,
          ),
        ],
      ),
    ],
    paymentMethod: OrderPaymentMethod.onDelivery,
    paymentStatus: OrderPaymentStatus.paid,
    subtotal: 36000,
    deliveryFee: 0,
    placedAt: DateTime(2026, 11, 7, 18, 32),
    statusChangedAt: DateTime(2026, 11, 7, 19, 5),
    addressLabel: 'Trabajo',
    landmark: 'Segundo local del puente hacia arriba',
    neighborhood: 'Centro',
  ),
  CustomerOrder(
    id: 'ord-4',
    serviceType: OrderServiceType.pickup,
    status: OrderStatus.done,
    items: const [
      OrderItem(
        productId: 'p-cachorro',
        productSlug: 'cachorro',
        name: 'El Cachorro',
        quantity: 1,
        unitPrice: 14000,
        includedNames: [
          'Pan brioche',
          'Salchicha americana',
          'Papas a la francesa',
        ],
      ),
    ],
    paymentMethod: OrderPaymentMethod.nequi,
    paymentStatus: OrderPaymentStatus.paid,
    subtotal: 14000,
    deliveryFee: 0,
    placedAt: DateTime(2026, 11, 4, 20, 15),
    statusChangedAt: DateTime(2026, 11, 4, 20, 40),
    storeReference: 'Depredadog — Costado norte del parque principal',
  ),
  CustomerOrder(
    id: 'ord-5',
    serviceType: OrderServiceType.delivery,
    status: OrderStatus.cancelled,
    cancelReason: 'Cancelado por el cliente',
    items: const [
      OrderItem(
        productId: 'p-ave',
        productSlug: 'ave-de-presa',
        name: 'Ave de Presa',
        quantity: 2,
        unitPrice: 18000,
        includedNames: ['Pan brioche', 'Pechuga apanada', 'Queso', 'Lechuga'],
      ),
    ],
    paymentMethod: OrderPaymentMethod.onDelivery,
    paymentStatus: OrderPaymentStatus.pending,
    subtotal: 36000,
    deliveryFee: 0,
    placedAt: DateTime(2026, 11, 1, 19, 0),
    statusChangedAt: DateTime(2026, 11, 1, 19, 3),
    landmark: 'Frente a la farmacia',
  ),
];

void main() {
  late MockLoadOrders loadOrders;
  late MockLoadMoreHistory loadMore;
  late MockGetOrderDetail getDetail;
  late MockCancelOrder cancelOrder;
  late OrdersDataResult loadResult;
  late OrdersCubit ordersCubit;
  late GoRouter router;

  OrdersCubit buildCubit() => OrdersCubit(
    loadOrdersUseCase: loadOrders,
    loadMoreHistoryUseCase: loadMore,
    getOrderDetailUseCase: getDetail,
    cancelOrderUseCase: cancelOrder,
  );

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

  setUp(() async {
    loadOrders = MockLoadOrders();
    loadMore = MockLoadMoreHistory();
    getDetail = MockGetOrderDetail();
    cancelOrder = MockCancelOrder();
    loadResult = OrdersDataResult(
      active: Right([_orderDelivery, _orderPickup, _orderDeliveryCash]),
      history: Right(OrdersHistoryPage(items: _history, total: 3)),
    );
    when(() => loadOrders.call()).thenAnswer((_) async => loadResult);
    when(() => loadMore.call(any())).thenAnswer(
      (_) async => Right(OrdersHistoryPage(items: const [], total: 3)),
    );
    when(() => getDetail.call(any()))
        .thenAnswer((_) async => Right(_orderPickup));
    when(() => cancelOrder.call('ord-2', any())).thenAnswer(
      (_) async => Right(
        _orderPickup.copyWith(
          status: OrderStatus.cancelled,
          statusChangedAt: DateTime(2026, 11, 8, 13, 30),
          cancelReason: 'Cancelado por el cliente',
        ),
      ),
    );
    ordersCubit = buildCubit();
    // §027 — la carga real corre en el pageBuilder del router; el
    // harness la gatilla igual que la app (datos antes de pintar).
    await ordersCubit.loadOrders();
    router = buildRouter();
  });

  tearDown(() {
    ordersCubit.close();
    router.dispose();
  });

  /// Harness: cubit REAL con use-cases mockeados (§027 — síncronos
  /// salvo el await del mock) + MaterialApp.router con l10n y el
  /// tema oscuro fijo.
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

  /// Detalle con CustomerOrder + el cubit (revisor-ui §023: el
  /// detalle puede cancelar — necesita el provider como la ruta
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
  }) async {
    // scrollUntilVisible frena cuando el elemento EXISTE (puede
    // quedar en el cacheExtent debajo del viewport); ensureVisible
    // lo trae a pantalla antes de cualquier tap.
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

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

  group('carga real (§027)', () {
    testWidgets('loading inicial → spinner tras el título hasta que '
        'loadOrders resuelve', (tester) async {
      // Cubit recién nacido: dataLoading arranca en true (no se ha
      // llamado loadOrders todavía).
      await ordersCubit.close();
      ordersCubit = buildCubit();
      await pumpOrders(tester);
      await tester.pump();

      expect(find.text('Pedidos'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ActiveOrderCard), findsNothing);

      await ordersCubit.loadOrders();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('En la plancha'), findsOneWidget);
    });

    testWidgets('ambas piernas fallan → fila inline de error+retry '
        'por sección; Reintentar recupera', (tester) async {
      loadResult = const OrdersDataResult(
        active: Left(OrdersOfflineFailure()),
        history: Left(OrdersOfflineFailure()),
      );
      await ordersCubit.loadOrders();
      await pumpOrders(tester);
      await tester.pumpAndSettle();

      // La zona activa (card) y bajo el heading Historial.
      expect(find.text('No pudimos cargar tus pedidos'), findsNWidgets(2));
      expect(find.text('Reintentar'), findsNWidgets(2));
      expect(find.text('Historial'), findsOneWidget);
      expect(find.byType(ActiveOrderCard), findsNothing);

      loadResult = OrdersDataResult(
        active: Right([_orderPickup]),
        history: Right(OrdersHistoryPage(items: _history, total: 3)),
      );
      await tester.tap(find.text('Reintentar').first);
      await tester.pumpAndSettle();

      expect(find.text('No pudimos cargar tus pedidos'), findsNothing);
      expect(find.text('Recibido'), findsOneWidget);
      expect(find.textContaining('7 nov'), findsOneWidget);
    });

    testWidgets('solo el historial falla → sus filas mueren pero las '
        'cards activas quedan (degrada por pierna)', (tester) async {
      loadResult = OrdersDataResult(
        active: Right([_orderDelivery]),
        history: const Left(OrdersServerFailure('boom')),
      );
      await ordersCubit.loadOrders();
      await pumpOrders(tester);
      await tester.pumpAndSettle();

      expect(find.text('En la plancha'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('No pudimos cargar tus pedidos'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.textContaining('7 nov'), findsNothing);
    });

    testWidgets('pull-to-refresh → loadOrders real de nuevo', (tester) async {
      await pumpOrders(tester);
      await tester.pumpAndSettle();

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      // called(2) = la carga del setUp + la del pull. Un verify
      // intermedio consumiría la invocación y la cuenta quedaría
      // en 1 aunque el refresh sí haya disparado loadOrders.
      verify(() => loadOrders.call()).called(2);
    });
  });

  group('"Cargar más" del historial (§027)', () {
    List<CustomerOrder> pageOf(int n, {int from = 0}) => [
      for (var i = 0; i < n; i++)
        CustomerOrder(
          id: 'ord-h${from + i}',
          serviceType: OrderServiceType.delivery,
          status: OrderStatus.done,
          items: const [
            OrderItem(
              productId: 'p-cachorro',
              productSlug: 'cachorro',
              name: 'El Cachorro',
              quantity: 1,
              unitPrice: 14000,
            ),
          ],
          paymentMethod: OrderPaymentMethod.nequi,
          paymentStatus: OrderPaymentStatus.paid,
          subtotal: 14000,
          deliveryFee: 0,
          placedAt: DateTime(2026, 10, 20, 19, 0),
        ),
    ];

    testWidgets('hasMore → botón al final; tap → acumula la página y '
        'al llegar al tope el botón desaparece', (tester) async {
      loadResult = OrdersDataResult(
        active: Right([_orderPickup]),
        history: Right(OrdersHistoryPage(items: pageOf(20), total: 25)),
      );
      final page2 = pageOf(5, from: 20);
      when(() => loadMore.call(2)).thenAnswer(
        (_) async => Right(OrdersHistoryPage(items: page2, total: 25)),
      );
      await ordersCubit.loadOrders();
      await pumpOrders(tester);
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Cargar más'), delta: 400);
      await tester.pumpAndSettle();
      expect(find.text('Cargar más'), findsOneWidget);

      await tester.tap(find.text('Cargar más'));
      await tester.pumpAndSettle();

      verify(() => loadMore.call(2)).called(1);
      expect(ordersCubit.state.history, hasLength(25));
      // Tope: ni botón ni error ni spinner.
      expect(find.text('Cargar más'), findsNothing);
      expect(find.text('No pudimos cargar más pedidos'), findsNothing);
    });

    testWidgets('la página falla → error+retry en la misma fila', (
      tester,
    ) async {
      loadResult = OrdersDataResult(
        active: Right([_orderPickup]),
        history: Right(OrdersHistoryPage(items: pageOf(20), total: 25)),
      );
      when(() => loadMore.call(2))
          .thenAnswer((_) async => const Left(OrdersOfflineFailure()));
      await ordersCubit.loadOrders();
      await pumpOrders(tester);
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Cargar más'), delta: 400);
      await tester.tap(find.text('Cargar más'));
      await tester.pumpAndSettle();

      expect(find.text('No pudimos cargar más pedidos'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Cargar más'), findsNothing);
      expect(ordersCubit.state.history, hasLength(20));
    });
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
    // cancelado (POST /orders/:id/cancel real — §027).
    verify(() => cancelOrder.call('ord-2', 'Cancelado por el cliente'))
        .called(1);
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
    verifyNever(() => cancelOrder.call(any(), any()));
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
    loadResult = OrdersDataResult(
      active: const Right(<CustomerOrder>[]),
      history: Right(OrdersHistoryPage(items: const [], total: 0)),
    );
    await ordersCubit.loadOrders();
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

  group('detalle del pedido (§027 — se resuelve por id del cubit)', () {
    testWidgets('delivery "En la plancha": secciones, ítems, referencia '
        'y totales con "Gratis" primary', (tester) async {
      await pumpDetail(tester, _orderDelivery);
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
      // §024 — línea "Recibe:" con el celular de contacto formateado
      // 3XX XXX XXXX (solo delivery).
      await scrollTo(tester, find.text('Recibe: 300 123 4567'));
      await tester.pumpAndSettle();
      expect(find.text('Recibe: 300 123 4567'), findsOneWidget);
      expect(find.text('Nequi · pagado'), findsWidgets);

      // Observación (solo existe porque el pedido la tiene).
      await scrollTo(tester, find.text('Observación'));
      await tester.pumpAndSettle();
      expect(find.text('Observación'), findsOneWidget);
      expect(find.text('pago con billete de 50, traer cambio'), findsOneWidget);
    });

    testWidgets('pickup "done": paso final se lee "Listo — ya puedes '
        'pasar" y no hay fila de domicilio', (tester) async {
      final pickupDone = _history.firstWhere((o) => o.id == 'ord-4');
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
      // §024 — pickup no lleva celular de contacto: la línea
      // "Recibe:" no existe.
      expect(find.textContaining('Recibe:'), findsNothing);
    });

    testWidgets('cancelado: chip + razón SIN stepper ni observación', (
      tester,
    ) async {
      final cancelled = _history.firstWhere((o) => o.id == 'ord-5');
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

    testWidgets('el detalle refleja el estado FRESCO del cubit — '
        'refreshOrder actualiza en vivo y la ventana de cancelar '
        'desaparece sola', (tester) async {
      await pumpOrders(tester);
      await tester.pumpAndSettle();

      // Tap en la card pickup (ord-2 "Recibido") → detalle con CTA.
      await scrollTo(tester, find.text('Local'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(of: find.text('Local'), matching: find.byType(InkWell)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(find.text('Cancelar pedido'), findsOneWidget);

      // El admin confirmó mientras tanto — refreshOrder trae el
      // estado nuevo y el detalle se re-resuelve por id.
      when(() => getDetail.call('ord-2')).thenAnswer(
        (_) async =>
            Right(_orderPickup.copyWith(status: OrderStatus.confirmed)),
      );
      await ordersCubit.refreshOrder('ord-2');
      await tester.pumpAndSettle();

      expect(find.text('Cancelar pedido'), findsNothing);
      expect(find.text('Confirmado'), findsOneWidget);
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
