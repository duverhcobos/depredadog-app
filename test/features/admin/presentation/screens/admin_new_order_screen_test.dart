import 'dart:async' show Completer, unawaited;
import 'dart:io' show Directory;

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/routes/auth_guard.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_new_order_draft.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/domain/failures/admin_failure.dart';
import 'package:depredadog_app/features/admin/domain/use_cases/load_admin_queue_use_case.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_new_order_cubit.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_queue_cubit.dart';
import 'package:depredadog_app/features/admin/domain/repositories/i_admin_repository.dart';
import 'package:depredadog_app/features/admin/presentation/screens/admin_new_order_screen.dart';
import 'package:depredadog_app/features/admin/presentation/screens/admin_queue_screen.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';
import 'package:depredadog_app/features/home/domain/entities/catalog_category.dart';
import 'package:depredadog_app/features/home/presentation/widgets/extra_stepper_row.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

import '../../fixtures/admin_new_order_fixtures.dart';
import '../../fixtures/admin_order_fixtures.dart';

void main() {
  final locator = GetIt.instance;
  late AdminQueueCubit queueCubit;
  late AdminNewOrderCubit cubit;
  late FakeCreateAdminOrderUseCase create;

  /// Cola con el use case propio para verificar el resync del
  /// éxito — el resto de use cases quedan silenciosos (no se
  /// ejercen en esta pantalla).
  late FakeLoadAdminQueueUseCase loadQueueUseCase;
  AdminQueueCubit buildQueue() {
    loadQueueUseCase = FakeLoadAdminQueueUseCase();
    when(() => loadQueueUseCase.call()).thenAnswer(
      (_) async => AdminQueueData(
        active: const Right([]),
        history: Right(AdminHistoryPage(items: const [], total: 0)),
      ),
    );
    return AdminQueueCubit(
      loadQueue: loadQueueUseCase,
      getOrderDetail: FakeGetAdminOrderDetailUseCase(),
      updateOrderStatus: FakeUpdateAdminOrderStatusUseCase(),
      confirmOrderPayment: FakeConfirmAdminOrderPaymentUseCase(),
      loadDayClose: FakeLoadAdminDayCloseUseCase(),
      closeDay: FakeCloseAdminDayUseCase(),
    );
  }

  setUpAll(() {
    registerFallbackValue(
      const AdminNewOrderDraft(
        serviceType: AdminServiceType.dineIn,
        paymentMethod: AdminPaymentMethod.cash,
        items: [],
      ),
    );
  });

  setUp(() {
    queueCubit = buildQueue();
    locator.registerSingleton<AdminQueueCubit>(queueCubit);
    create = FakeCreateAdminOrderUseCase();
    when(() => create.call(any())).thenAnswer(
      (_) async => Right<AdminFailure, AdminOrder>(newOrderCreated()),
    );
    cubit = buildAdminNewOrderCubit(createOrder: create);
    // La ruta real resuelve el cubit por locator — el test replica
    // la rama admin completa.
    locator.registerFactory<AdminNewOrderCubit>(() => cubit);
  });

  tearDown(() async {
    // NO awaitear el close del cubit factory: su `done` de
    // broadcast puede quedar pendiente de un turn de FakeAsync que
    // el tearDown ya no corre (cuelga el test). El cubit muere con
    // el isolate; locator.reset() lo suelta del DI.
    unawaited(cubit.close());
    await queueCubit.close();
    await locator.reset();
  });

  List<MethodCall> stubToast(WidgetTester tester) {
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
    return calls;
  }

  /// Intercepta share_plus (dev.fluttercommunity.plus/share) — el
  /// share sheet no abre en test; el stub confirma la entrega de
  /// las cards PNG (`paths`) al chooser del SO. `fail` lanza
  /// PlatformException para ejercitar el toast de fallo (§043 v2).
  List<MethodCall> stubShare(WidgetTester tester, {bool fail = false}) {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      if (fail) throw PlatformException(code: 'share_failed');
      return 'dev.fluttercommunity.plus/share/success';
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    return calls;
  }

  /// path_provider → temp dir real del SO — shareKitchenItemCards
  /// escribe las PNG antes del share (§043 v2; sin stub el canal
  /// no responde en test).
  void stubPathProvider(WidgetTester tester) {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'getTemporaryDirectory'
          ? Directory.systemTemp.path
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
  }

  /// Rama admin réplica de app_router — 'orders/new' ANTES de la
  /// pantalla, con el cubit factory por locator igual que prod.
  GoRouter buildAdminRouter() => GoRouter(
    initialLocation: AuthGuard.adminRoute,
    routes: [
      GoRoute(
        path: AuthGuard.adminRoute,
        builder: (context, state) => const AdminQueueScreen(),
        routes: [
          GoRoute(
            path: 'orders/new',
            builder: (context, state) => BlocProvider(
              create: (_) => locator<AdminNewOrderCubit>(),
              child: const AdminNewOrderScreen(),
            ),
          ),
        ],
      ),
    ],
  );

  /// Superficie alta — el cobro tiene ticket + secciones + campos;
  /// sin alto extra los finds no ven los de abajo. Además deja la
  /// cola cargada: si quedara en loading, al volver de la comanda
  /// el spinner de Cocina agenda frames para siempre y cualquier
  /// pumpAndSettle del regreso colgaría.
  Future<void> pumpAdminApp(WidgetTester tester, GoRouter router) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp.router(
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
    );
    final load = queueCubit.load();
    await tester.pump();
    await load;
  }

  /// Push a la comanda y espera el load() de initState (los stubs
  /// resuelven en microtask).
  Future<void> openNewOrder(WidgetTester tester, GoRouter router) async {
    router.push('${AuthGuard.adminRoute}/orders/new');
    await tester.pumpAndSettle();
  }

  /// Agrega El Cachorro por el sheet completo: fila → sheet →
  /// quitar Cebolla + Tocineta → "Agregar · $18.000" — cierra al
  /// producir el CartItem.
  Future<void> addCachorro(WidgetTester tester) async {
    await tester.tap(find.text('El Cachorro'));
    await tester.pumpAndSettle();
    expect(find.text('¿Se le quita algo?'), findsOneWidget);
    await tester.tap(find.text('Cebolla'));
    await tester.pump();
    // Extra con stepper (§045): el + de la fila de Tocineta la agrega
    // en 1 porción — el tap sobre el nombre ya no alterna.
    final tocinetaRow = find.widgetWithText(
      ExtraStepperRow,
      'Tocineta crocante',
    );
    await tester.ensureVisible(tocinetaRow);
    await tester.pump();
    await tester.tap(
      find.descendant(of: tocinetaRow, matching: find.byIcon(Icons.add_rounded)),
    );
    await tester.pump();
    await tester.tap(find.text('Agregar · \$18.000'));
    await tester.pumpAndSettle();
  }

  /// Deja la pantalla en la vista de éxito (§043): Cachorro por el
  /// sheet → cobro → Mesa 2 → "Crear pedido" (el stub devuelve el
  /// pedido #8 de `newOrderCreated`).
  Future<void> reachSuccessView(WidgetTester tester, GoRouter router) async {
    await openNewOrder(tester, router);
    await addCachorro(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mesa 2'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  testWidgets('comanda: título, chips de categoría, productos y '
      'footer disabled en 0 ítems', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await openNewOrder(tester, router);

    expect(find.text('Nueva orden'), findsOneWidget);
    expect(find.text('Todo'), findsOneWidget);
    expect(find.text('Perros'), findsOneWidget);
    expect(find.text('Más'), findsOneWidget);
    expect(find.text('El Cachorro'), findsOneWidget);
    expect(find.text('Manada de papas'), findsOneWidget);
    // Footer §020: resumen a la izquierda, acción limpia a la
    // derecha — dato y CTA no se funden (decisión del dueño §042).
    expect(find.text('0 ítems'), findsOneWidget);
    expect(find.text(r'$0'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    // El footer de la comanda es el ÚNICO FilledButton en pantalla.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('comanda: el filtro de categoría achica la lista y '
      '"Todo" la restaura', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await openNewOrder(tester, router);

    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    expect(find.text('El Cachorro'), findsNothing);
    expect(find.text('Manada de papas'), findsOneWidget);

    await tester.tap(find.text('Todo'));
    await tester.pumpAndSettle();
    expect(find.text('El Cachorro'), findsOneWidget);
  });

  testWidgets('sheet: abre del tap del producto, personaliza y el '
      'CartItem llega al borrador (footer cuenta)', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await openNewOrder(tester, router);

    await addCachorro(tester);

    // El borrador recibió el ítem — qty 1, 2 modifiers
    // (cebolla removed + tocineta added) y el footer cuenta.
    expect(cubit.state.items, hasLength(1));
    expect(cubit.state.items.single.modifiers, hasLength(2));
    expect(
      cubit.state.items.single.modifiers.first.action,
      CartModifierAction.removed,
    );
    expect(find.text('1 ítem'), findsOneWidget);
    expect(find.text(r'$18.000'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('cobro: ticket con la fila del carrito, mesas con '
      'ocupada "#N" disabled e inactiva atenuada', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await openNewOrder(tester, router);
    await addCachorro(tester);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('Revisar y cobrar'), findsOneWidget);
    expect(find.text('El Cachorro'), findsOneWidget);
    expect(find.text('Servicio'), findsOneWidget);
    expect(find.text('Mesa'), findsWidgets);
    expect(find.text('Para llevar'), findsOneWidget);
    expect(find.text('Mesa 1'), findsOneWidget);
    expect(find.text('Mesa 2'), findsOneWidget);
    // Ocupada → "Mesa 3 · #7" y no entra al borrador ni por tap.
    expect(find.text('Mesa 3 · #7'), findsOneWidget);
    expect(find.text('Mesa 4'), findsOneWidget);
    expect(find.text('Pago'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Transf.'), findsOneWidget);

    // dineIn por defecto SIN mesa → "Crear pedido" disabled.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    // La ocupada no selecciona aunque el tap llegue.
    await tester.tap(find.text('Mesa 3 · #7'));
    await tester.pump();
    expect(cubit.state.selectedTableId, isNull);

    await tester.tap(find.text('Mesa 2'));
    await tester.pump();
    expect(cubit.state.selectedTableId, 't-2');
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('cobro: Transf. revela el celular y lo exige; Para '
      'llevar no pide mesa', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await openNewOrder(tester, router);
    await addCachorro(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // Sin celular visible hasta Transf.
    expect(find.text('Celular que recibe el cobro'), findsNothing);

    await tester.tap(find.text('Para llevar'));
    await tester.pumpAndSettle();
    // Las mesas se esconden en pickup y la puerta se abre sin mesa.
    expect(find.text('Mesa 2'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Transf.'));
    await tester.pumpAndSettle();
    expect(find.text('Celular que recibe el cobro'), findsOneWidget);
    // Transfer sin celular válido → disabled.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ej: 3001234567'),
      '3001234567',
    );
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('submit éxito: VISTA de éxito "Pedido #adm-8 creado" con '
      'compartir + volver — reemplazó al toast+pop del §042 (§043)', (
    tester,
  ) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await reachSuccessView(tester, router);

    // La pantalla NO popeó — la vista de éxito ofrece mandar la
    // comanda al chat de cocina antes de volver (decisión del dueño).
    expect(find.byType(AdminNewOrderScreen), findsOneWidget);
    expect(find.text('Pedido #adm-8 creado'), findsOneWidget);
    expect(find.text('Enviar a cocina'), findsOneWidget);
    expect(find.text('Volver a Cocina'), findsOneWidget);
    // Los pasos quedaron atrás — el footer "Crear pedido" también
    // se esconde en éxito (como en loading/failed).
    expect(find.text('Crear pedido'), findsNothing);
    expect(cubit.state.createdOrder?.orderNumber, 8);

    // El POST recibió el draft dineIn + mesa + cash — UNA sola vez
    // (la vista de éxito no lo re-dispara).
    final draft =
        verify(() => create.call(captureAny())).captured.single
            as AdminNewOrderDraft;
    expect(draft.serviceType, AdminServiceType.dineIn);
    expect(draft.tableId, 't-2');
    expect(draft.paymentMethod, AdminPaymentMethod.cash);
    // Resync de la cola — el singleton recargó igual que antes (uno
    // por el load inicial del pump, otro por el éxito).
    verify(() => loadQueueUseCase.call()).called(2);
  });

  testWidgets('vista de éxito: "Enviar a cocina" lanza el share '
      'sheet con UNA card PNG por ítem del BORRADOR (§043 v2)', (tester) async {
    stubPathProvider(tester);
    final shares = stubShare(tester);
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await reachSuccessView(tester, router);

    // runAsync: el render de las cards usa toImage/toByteData +
    // writeAsBytes — async real del engine/IO que no progresa en la
    // zona fake de testWidgets; los pumps manuales dan los frames
    // que espera cada endOfFrame del overlay offscreen y el delayed
    // cede al event loop real para que el IO de las PNG aterrice.
    await tester.runAsync(() async {
      await tester.tap(find.text('Enviar a cocina'));
      for (var i = 0; i < 200 && shares.isEmpty; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    await tester.pumpAndSettle();

    // Una imagen por ítem del borrador — la card es self-contained
    // (decisión del dueño v2: imagen, no texto wa.me).
    final call = shares.firstWhere((c) => c.method == 'share');
    final paths = (call.arguments['paths'] as List).cast<String>();
    expect(paths, hasLength(cubit.state.items.length));
    expect(paths.every((p) => p.endsWith('.png')), isTrue);
    // La orden sigue viva en pantalla y el POST no se re-disparó.
    expect(find.byType(AdminNewOrderScreen), findsOneWidget);
    verify(() => create.call(any())).called(1);
  });

  testWidgets('vista de éxito: exception del share sheet → toast "No '
      'pudimos compartir la comanda" (§043 v2)', (tester) async {
    final calls = stubToast(tester);
    stubPathProvider(tester);
    stubShare(tester, fail: true);
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await reachSuccessView(tester, router);

    // runAsync — el render de las cards es async real del engine/IO
    // (ver el test del share arriba); aquí se espera el TOAST del
    // catch, no la llamada share.
    await tester.runAsync(() async {
      await tester.tap(find.text('Enviar a cocina'));
      for (var i = 0; i < 200 && calls.isEmpty; i++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    await tester.pumpAndSettle();

    expect(
      calls.any((c) => c.arguments['msg'] == 'No pudimos compartir la comanda'),
      isTrue,
    );
    // Se queda en la vista de éxito para reintentar o volver.
    expect(find.text('Pedido #adm-8 creado'), findsOneWidget);

    // Expira el Future.delayed interno de fluttertoast.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('vista de éxito: "Volver a Cocina" hace pop a la cola '
      '(el resync ya corrió en el éxito — §043)', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await reachSuccessView(tester, router);

    await tester.tap(find.text('Volver a Cocina'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminNewOrderScreen), findsNothing);
    expect(find.byType(AdminQueueScreen), findsOneWidget);
    verify(() => create.call(any())).called(1);
  });

  testWidgets('vista de éxito: el back NATIVO hace pop directo a '
      'Cocina — la regla cobro→comanda no aplica (§043)', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await reachSuccessView(tester, router);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AdminNewOrderScreen), findsNothing);
    expect(find.byType(AdminQueueScreen), findsOneWidget);
  });

  testWidgets('submit TABLE_NOT_FOUND: toast "la mesa cambió" y la '
      'pantalla se QUEDA (§042)', (tester) async {
    final calls = stubToast(tester);
    when(() => create.call(any())).thenAnswer(
      (_) async =>
          const Left(AdminServerFailure('nf', errorCode: 'TABLE_NOT_FOUND')),
    );
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await openNewOrder(tester, router);
    await addCachorro(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mesa 2'));
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(
      calls.any((c) => c.arguments['msg'] == 'La mesa cambió — elige otra'),
      isTrue,
    );
    expect(find.byType(AdminNewOrderScreen), findsOneWidget);
    // submitting liberado y el borrador sobrevive.
    expect(cubit.state.submitting, isFalse);
    expect(cubit.state.items, isNotEmpty);
    // La cola solo cargó la vez del pump inicial — el resync del
    // éxito NO corre en fallo (solo las mesas se resincronizan).
    verify(() => loadQueueUseCase.call()).called(1);

    // Expira el Future.delayed interno de fluttertoast.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('submit error genérico: toast de la cola y se queda', (
    tester,
  ) async {
    final calls = stubToast(tester);
    when(() => create.call(any()))
        .thenAnswer((_) async => const Left(AdminOfflineFailure()));
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await openNewOrder(tester, router);
    await addCachorro(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mesa 2'));
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(
      calls.any(
        (c) =>
            c.arguments['msg'] ==
            'No pudimos actualizar el pedido — inténtalo de nuevo',
      ),
      isTrue,
    );
    expect(find.byType(AdminNewOrderScreen), findsOneWidget);

    // Expira el Future.delayed interno de fluttertoast.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('flecha atrás: cobro devuelve a comanda sin perder el '
      'borrador; comanda hace pop a Cocina', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await openNewOrder(tester, router);
    await addCachorro(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Nueva orden'), findsOneWidget);
    expect(cubit.state.items, isNotEmpty);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(AdminNewOrderScreen), findsNothing);
    expect(find.byType(AdminQueueScreen), findsOneWidget);
  });

  testWidgets('back NATIVO: en cobro devuelve a comanda sin perder '
      'el borrador; en comanda sale a Cocina (PopScope §042 — '
      'revisor-ui CRÍTICO)', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await openNewOrder(tester, router);
    await addCachorro(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Revisar y cobrar'), findsOneWidget);

    // Back del SISTEMA en cobro — antes popeaba la ruta entera y
    // la comanda armada se destruía en silencio.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AdminNewOrderScreen), findsOneWidget);
    expect(find.text('Nueva orden'), findsOneWidget);
    expect(cubit.state.items, isNotEmpty);

    // En comanda el back nativo sale a Cocina (context.pop
    // bypassea el PopScope — patrón product_detail).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AdminNewOrderScreen), findsNothing);
    expect(find.byType(AdminQueueScreen), findsOneWidget);
  });

  testWidgets('submit en vuelo: el CTA NO se apaga a gris — spinner '
      'onPrimary visible y doble-tap bloqueado (revisor-ui §042 — '
      'misma regresión del §035)', (tester) async {
    final gate = Completer<Either<AdminFailure, AdminOrder>>();
    when(() => create.call(any())).thenAnswer((_) => gate.future);
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await openNewOrder(tester, router);
    await addCachorro(tester);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mesa 2'));
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    // En vuelo: spinner visible y el botón queda primary (el
    // IgnorePointer de la pantalla bloquea los taps — no hace
    // falta apagarlo a gris).
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(cubit.state.submitting, isTrue);
    // El segundo tap no re-entra al POST (warnIfMissed: el tap
    // cae sobre el IgnorePointer — es justo lo que se verifica).
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    verify(() => create.call(any())).called(1);

    gate.complete(Right<AdminFailure, AdminOrder>(newOrderCreated()));
    await tester.pumpAndSettle();
    // Expira el Future.delayed interno de fluttertoast.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('comanda: categoría sin productos → "Sin productos en '
      'esta categoría" en zona negra (revisor-ui §042 — antes el '
      'área quedaba en negro mudo)', (tester) async {
    // Re-registra el factory con una carta que trae una categoría
    // vacía (la real tiene "Bebidas 0").
    locator.unregister<AdminNewOrderCubit>();
    cubit = buildAdminNewOrderCubit(
      createOrder: create,
      categories: [
        ...newOrderCategories(),
        CatalogCategory(
          id: 'cat-bebidas',
          slug: 'bebidas',
          name: 'Bebidas',
          products: const [],
        ),
      ],
    );
    locator.registerFactory<AdminNewOrderCubit>(() => cubit);
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router);
    await openNewOrder(tester, router);

    await tester.tap(find.text('Bebidas'));
    await tester.pumpAndSettle();
    expect(find.text('Sin productos en esta categoría'), findsOneWidget);
    expect(find.text('El Cachorro'), findsNothing);
  });
}
