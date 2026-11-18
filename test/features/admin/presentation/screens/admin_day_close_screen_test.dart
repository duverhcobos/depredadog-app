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
import 'package:depredadog_app/features/admin/domain/entities/admin_day_close.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/domain/failures/admin_failure.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_queue_cubit.dart';
import 'package:depredadog_app/features/admin/presentation/screens/admin_day_close_screen.dart';
import 'package:depredadog_app/features/admin/presentation/screens/admin_history_screen.dart';
import 'package:depredadog_app/features/admin/presentation/screens/admin_order_detail_screen.dart';
import 'package:depredadog_app/features/admin/presentation/screens/admin_queue_screen.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

import '../../fixtures/admin_order_fixtures.dart';

void main() {
  final locator = GetIt.instance;
  late AdminQueueCubit cubit;

  setUp(() {
    cubit = buildAdminQueueCubit();
    locator.registerSingleton<AdminQueueCubit>(cubit);
  });

  tearDown(() async {
    await cubit.close();
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

  /// Router de la rama admin — réplica de app_router con el ORDEN
  /// real de declaración (day-close y history ANTES de :id): si el
  /// orden se rompiera, ':id' tragaría los literales y su redirect
  /// (extra no-AdminOrder) devolvería a /admin.
  GoRouter buildAdminRouter() => GoRouter(
    initialLocation: AuthGuard.adminRoute,
    routes: [
      GoRoute(
        path: AuthGuard.adminRoute,
        builder: (context, state) => const AdminQueueScreen(),
        routes: [
          GoRoute(
            path: 'day-close',
            builder: (context, state) => BlocProvider.value(
              value: locator<AdminQueueCubit>(),
              child: const AdminDayCloseScreen(),
            ),
          ),
          GoRoute(
            path: 'history',
            builder: (context, state) => BlocProvider.value(
              value: locator<AdminQueueCubit>(),
              child: const AdminHistoryScreen(),
            ),
          ),
          GoRoute(
            path: ':id',
            redirect: (context, state) =>
                state.extra is AdminOrder ? null : AuthGuard.adminRoute,
            builder: (context, state) => BlocProvider.value(
              value: locator<AdminQueueCubit>(),
              child: AdminOrderDetailScreen(order: state.extra! as AdminOrder),
            ),
          ),
        ],
      ),
    ],
  );

  Future<void> pumpAdminApp(WidgetTester tester, {GoRouter? router}) =>
      tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: router ?? buildAdminRouter(),
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

  /// Deja la cola cargada (el stub del use case resuelve en
  /// microtask — §038 sin delay).
  Future<void> loadQueue(WidgetTester tester) async {
    final load = cubit.load();
    await tester.pump(const Duration(milliseconds: 500));
    await load;
    await tester.pumpAndSettle();
  }

  testWidgets('preview del cierre: total, # pedidos, por método y '
      'cancelados como contexto (§036)', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);

    router.push('${AuthGuard.adminRoute}/day-close');
    await tester.pumpAndSettle();

    expect(find.byType(AdminDayCloseScreen), findsOneWidget);
    expect(find.text('Cierre de caja'), findsOneWidget);
    expect(find.text('Vendido hoy'), findsOneWidget);
    // Tres done sin cerrar: adm-16 ($26.000 cash), adm-17 y adm-5
    // ($39.000 transfer) — hero del total $65.000.
    expect(find.text('\$65.000'), findsOneWidget);
    expect(find.text('3 pedidos entregados'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('1 · \$26.000'), findsOneWidget);
    expect(find.text('Transf.'), findsOneWidget);
    expect(find.text('2 · \$39.000'), findsOneWidget);
    // Tres cancelados $85.000 — contexto, no suman al total.
    expect(find.text('3 cancelados · \$85.000'), findsOneWidget);
    expect(find.text('Confirmar cierre'), findsOneWidget);
    // El preview NO archivó nada.
    expect(cubit.state.deliveredCount, 3);
  });

  testWidgets('confirmar cierre: busy → resultado con check + resumen '
      'fijo + "Listo" hace pop a Cocina (§036)', (tester) async {
    final calls = stubToast(tester);
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);

    router.push('${AuthGuard.adminRoute}/day-close');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar cierre'));
    // El cierre local es instantáneo en esta fase (PROVISIONAL §038
    // — sin delay; la latencia real la pondrá el POST /admin/day-close).
    await tester.pumpAndSettle();

    // Resultado: check + el resumen queda fijo (aunque el cubit ya
    // archivó los done) + "Listo" reemplaza al CTA.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('\$65.000'), findsOneWidget);
    expect(find.text('Listo'), findsOneWidget);
    expect(find.text('Confirmar cierre'), findsNothing);
    expect(
      calls.any((c) => c.arguments['msg'] == 'Día cerrado — \$65.000'),
      isTrue,
    );
    // El carril Entregado quedó vacío de verdad — los done al
    // FRENTE del historial, el más reciente primero (§041).
    expect(cubit.state.deliveredCount, 0);
    expect(cubit.state.history.first.id, 'adm-5');

    // "Listo" → pop a Cocina: el header ya no muestra el contador
    // (no hay entregados esperando cierre).
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminDayCloseScreen), findsNothing);
    expect(find.byType(AdminQueueScreen), findsOneWidget);
    // El badge de entregados quedó oculto — el ícono limpio.
    expect(find.byIcon(Icons.point_of_sale_rounded), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('3')),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('preview fallido: vista de error + Reintentar re-pide '
      'el GET /admin/day-close (§041 — sin el flag era spinner '
      'eterno)', (tester) async {
    await cubit.close();
    await locator.reset();
    final preview = FakeLoadAdminDayCloseUseCase();
    when(() => preview.call()).thenAnswer(
      (_) async => const Left(AdminOfflineFailure()),
    );
    cubit = buildAdminQueueCubit(loadDayClose: preview);
    locator.registerSingleton<AdminQueueCubit>(cubit);

    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);

    router.push('${AuthGuard.adminRoute}/day-close');
    await tester.pumpAndSettle();

    // Error en la zona negra — ni spinner ni resumen.
    expect(find.text('No pudimos cargar el cierre'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // El CTA queda DESHABILITADO — sin resumen no se cierra a
    // ciegas (revisor §041).
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirmar cierre'),
          )
          .onPressed,
      isNull,
    );
    verify(() => preview.call()).called(1);

    // Reintento con el canal sano → segundo GET y el resumen llega.
    stubLoadDayClose(
      preview,
      adminActiveFixtures(),
      adminHistoryFixtures(),
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    // UN GET nuevo (verify solo cuenta llamadas aún no
    // verificadas — la primera ya quedó marcada arriba).
    verify(() => preview.call()).called(1);
    expect(find.text('No pudimos cargar el cierre'), findsNothing);
    expect(find.text('\$65.000'), findsOneWidget);
    expect(find.text('Confirmar cierre'), findsOneWidget);
    // Con el resumen visible el CTA vuelve a habilitarse.
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirmar cierre'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('el cierre falla: toast de error y la pantalla se '
      'QUEDA en el preview (§041 — decisión: no vuelve sola)', (
    tester,
  ) async {
    final calls = stubToast(tester);
    await cubit.close();
    await locator.reset();
    final close = FakeCloseAdminDayUseCase();
    when(() => close.call()).thenAnswer(
      (_) async => const Left(AdminServerFailure('boom')),
    );
    cubit = buildAdminQueueCubit(closeDay: close);
    locator.registerSingleton<AdminQueueCubit>(cubit);

    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);

    router.push('${AuthGuard.adminRoute}/day-close');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar cierre'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Toast de error específico del cierre — NUNCA el de éxito.
    expect(
      calls.any(
        (c) =>
            c.arguments['msg'] ==
            'No pudimos cerrar la caja — inténtalo de nuevo',
      ),
      isTrue,
    );
    expect(
      calls.any((c) => (c.arguments['msg'] as String?)?.startsWith('Día cerrado') ?? false),
      isFalse,
    );
    // Sigue en el preview — sin check ni "Listo", el CTA vuelve.
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.text('\$65.000'), findsOneWidget);
    expect(find.text('Confirmar cierre'), findsOneWidget);
    expect(find.text('Listo'), findsNothing);
    // Los done NO se archivaron.
    expect(cubit.state.deliveredCount, 3);
    expect(cubit.state.dayCloseBusy, isFalse);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('éxito: el resumen mostrado es el SNAPSHOT DEL '
      'SERVIDOR del POST, no el preview local (§041)', (tester) async {
    await cubit.close();
    await locator.reset();
    // El servidor devuelve un snapshot distinto del preview local
    // (un pedido terminó entre el GET y el POST — el claim atómico
    // lo incluyó).
    const serverSummary = AdminDayClose(
      orderCount: 4,
      totalAmount: 99000,
      byMethod: [
        AdminDayCloseMethod(method: 'cash', count: 2, amount: 60000),
        AdminDayCloseMethod(method: 'transfer', count: 2, amount: 39000),
      ],
      cancelledCount: 3,
      cancelledAmount: 85000,
    );
    final close = FakeCloseAdminDayUseCase();
    when(
      () => close.call(),
    ).thenAnswer((_) async => const Right(serverSummary));
    cubit = buildAdminQueueCubit(closeDay: close);
    locator.registerSingleton<AdminQueueCubit>(cubit);

    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);

    router.push('${AuthGuard.adminRoute}/day-close');
    await tester.pumpAndSettle();
    // El preview mostraba \$65.000 (3 pedidos) — el servidor cerró 4.
    expect(find.text('\$65.000'), findsOneWidget);

    await tester.tap(find.text('Confirmar cierre'));
    await tester.pumpAndSettle();

    // El estado de éxito pinta el snapshot del POST — \$99.000 y
    // 4 pedidos, no los del preview.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('\$99.000'), findsOneWidget);
    expect(find.text('4 pedidos entregados'), findsOneWidget);
    expect(find.text('\$65.000'), findsNothing);
    expect(find.text('Listo'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('cierre vacío permitido: resumen en ceros con su nota '
      '(decisión del dueño)', (tester) async {
    await cubit.close();
    await locator.reset();
    // Cola sin entregados: un solo pedido vivo en la plancha.
    cubit = buildAdminQueueCubit(
      active: [
        AdminOrder(
          id: 'solo',
          channel: AdminOrderChannel.presencial,
          serviceType: AdminServiceType.dineIn,
          status: OrderStatus.preparing,
          items: const [],
          paymentMethod: AdminPaymentMethod.cash,
          paymentStatus: OrderPaymentStatus.paid,
          subtotal: 10000,
          deliveryFee: 0,
          placedAt: DateTime(2024, 1, 1),
        ),
      ],
      history: const [],
    );
    locator.registerSingleton<AdminQueueCubit>(cubit);

    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);

    router.push('${AuthGuard.adminRoute}/day-close');
    await tester.pumpAndSettle();

    expect(find.text('0 pedidos entregados'), findsOneWidget);
    expect(
      find.text(
        'Cierre del día — sin pedidos entregados. El registro queda '
        'como bitácora.',
      ),
      findsOneWidget,
    );

    // Confirmar también funciona — el registro queda como bitácora.
    await tester.tap(find.text('Confirmar cierre'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    // El pedido en curso NO se archivó — el cierre solo toca done.
    expect(cubit.state.active.any((o) => o.id == 'solo'), isTrue);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('rutas literales resuelven ANTES que :id — day-close e '
      'history no caen al redirect del detalle', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);

    // Sin extra AdminOrder: si ':id' se tragara 'day-close', su
    // redirect devolvería a /admin (queue, no la pantalla).
    router.push('${AuthGuard.adminRoute}/day-close');
    await tester.pumpAndSettle();
    expect(find.byType(AdminDayCloseScreen), findsOneWidget);
    expect(router.state.matchedLocation, '${AuthGuard.adminRoute}/day-close');
    router.pop();
    await tester.pumpAndSettle();

    router.push('${AuthGuard.adminRoute}/history');
    await tester.pumpAndSettle();
    expect(find.byType(AdminHistoryScreen), findsOneWidget);
    expect(router.state.matchedLocation, '${AuthGuard.adminRoute}/history');
  });
}
