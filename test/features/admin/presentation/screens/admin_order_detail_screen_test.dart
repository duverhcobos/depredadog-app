import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:depredadog_app/core/routes/auth_guard.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_queue_cubit.dart';
import 'package:depredadog_app/features/admin/presentation/screens/admin_day_close_screen.dart';
import 'package:depredadog_app/features/admin/presentation/screens/admin_history_screen.dart';
import 'package:depredadog_app/features/admin/presentation/screens/admin_order_detail_screen.dart';
import 'package:depredadog_app/features/admin/presentation/screens/admin_queue_screen.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  final locator = GetIt.instance;
  late AdminQueueCubit cubit;

  setUp(() {
    // Cubit REAL con la semilla mock — el detalle lee la orden viva
    // por id sobre la misma instancia que alimenta la cola.
    cubit = AdminQueueCubit();
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

  /// Intercepta Clipboard.setData (SystemChannels.platform) — mismo
  /// patrón de los tests de perfil (loyalty card / store).
  List<String?> stubClipboard(WidgetTester tester) {
    final copied = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String?);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return copied;
  }

  /// Intercepta url_launcher (plugins.flutter.io/url_launcher) —
  /// el tap del pin pide abrir Maps; el stub confirma el launch
  /// sin intentar resolver el intent del SO.
  List<MethodCall> stubUrlLauncher(WidgetTester tester) {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
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

  /// Router de la rama admin — réplica de app_router (la hija :id
  /// con su redirect de extra y el BlocProvider.value del cubit
  /// compartido), mismo patrón que la réplica de branches del test
  /// del shell.
  GoRouter buildAdminRouter() => GoRouter(
    initialLocation: AuthGuard.adminRoute,
    routes: [
      GoRoute(
        path: AuthGuard.adminRoute,
        builder: (context, state) => const AdminQueueScreen(),
        routes: [
          // Réplica del ORDEN real de app_router (§036): literales
          // antes de ':id' o el parámetro las traga.
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

  /// Deja la cola cargada (venzan los 400ms del mock).
  Future<void> loadQueue(WidgetTester tester) async {
    final load = cubit.load();
    await tester.pump(const Duration(milliseconds: 500));
    await load;
    await tester.pumpAndSettle();
  }

  /// Abre el detalle de un pedido por push con extra — lo que hace
  /// el InkWell de la card.
  Future<void> openDetail(
    WidgetTester tester,
    GoRouter router,
    String orderId,
  ) async {
    router.push(
      '${AuthGuard.adminRoute}/$orderId',
      extra: cubit.state.orderById(orderId),
    );
    await tester.pumpAndSettle();
  }

  /// Trae un widget del detalle a zona tappeable — scrollUntilVisible
  /// puede dejarlo justo al filo del viewport (su centro queda fuera
  /// de los 800×600 del tester y el tap falla), el drag extra lo
  /// sube a la zona segura.
  Future<void> scrollToTappable(WidgetTester tester, Finder what) async {
    await tester.scrollUntilVisible(
      what,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
  }

  testWidgets('tap en card → detalle del pedido con sus chips, '
      'cliente y #id (§035)', (tester) async {
    await pumpAdminApp(tester);
    await loadQueue(tester);

    // Mesa 3 queda bajo el fold — Ana Uno (primera) navega igual.
    await tester.tap(find.text('Ana Uno'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminOrderDetailScreen), findsOneWidget);
    expect(find.text('Detalle del pedido'), findsOneWidget);
    expect(find.text('Pedido'), findsOneWidget); // sección header
    expect(find.text('#adm-1'), findsOneWidget);
    expect(find.text('Ana Uno'), findsOneWidget);
    // El detalle muestra los dos chips: canal (Online) + servicio
    // (Domicilio) — en la card solo vive el de servicio.
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Domicilio'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('hace 12 min'), findsOneWidget);
  });

  testWidgets('detalle de Mesa 5: los 7 ítems completos uno por '
      'fila + total', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);
    await openDetail(tester, router, 'adm-7');

    expect(find.text('En el local · Mesa 5'), findsOneWidget);
    expect(find.text('#adm-7'), findsOneWidget);

    const items = [
      '1× El Depredador',
      '1× El Carnicero',
      '1× El Coyote',
      '1× Ave de Presa',
      '1× La Trampa',
      '1× El Cachorro',
      '1× Manada de Papas',
    ];
    for (final item in items) {
      await tester.scrollUntilVisible(
        find.text(item),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(item), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.text(r'$118.000').last,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Solo el Total — la mesa no paga domicilio y el Subtotal se
    // deduplica (§037: sin fila Domicilio no hay nada que separar).
    expect(find.text(r'$118.000'), findsOneWidget);
  });

  testWidgets('ready + pago pendiente: "Entregado" DESHABILITADO con '
      'pista "Toca Registrar pago primero" y primario "Registrar pago" (§036)', (
    tester,
  ) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);
    // Mesa 7 — ready + efectivo pendiente: el cobro bloquea el
    // Entregado (único caso donde "Registrar pago" es el primario, §036).
    await openDetail(tester, router, 'adm-8');

    // El avance real es cobrar: primario "Registrar pago" — y el tonal de
    // la fila de pago se SUPRIME porque la matriz ya lo pone como
    // primario (eco de composición, revisor-estetico §035).
    expect(find.text('Registrar pago'), findsOneWidget);

    // "Entregado" presente pero bloqueado, con su pista — adelanta
    // la regla del backend (done exige pago) en vez de fallar con
    // 409.
    final doneButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Entregado'),
    );
    expect(doneButton.onPressed, isNull);
    expect(find.text('Registra el pago primero'), findsOneWidget);
  });

  testWidgets('confirmado + pago pendiente: "Preparar" primario Y '
      '"Registrar pago" tonal — en mesa se sirve antes de cobrar (§036)', (
    tester,
  ) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);
    // Mesa 3 — confirmed + efectivo pendiente: el cobro dejó de ser
    // la acción de card/detalle en estados tempranos; vive como el
    // tonal manual de la sección de pago.
    await openDetail(tester, router, 'adm-2');

    expect(find.widgetWithText(FilledButton, 'Preparar'), findsOneWidget);
    expect(find.text('Registrar pago'), findsOneWidget);
    // Sin puerta de pago todavía — "Entregado" no aparece bloqueado.
    expect(find.text('Registra el pago primero'), findsNothing);
  });

  testWidgets('pendiente + pago pendiente: "Confirmar" primario Y '
      '"Registrar pago" tonal — acciones distintas (§035)', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);
    // Ana Uno — received + transferencia pendiente: cobrar antes de
    // confirmar es una acción válida y DISTINTA del primario. El
    // delivery sin cobrar NO se bloquea — la puerta solo es de la
    // recogida.
    await openDetail(tester, router, 'adm-1');

    expect(find.widgetWithText(FilledButton, 'Confirmar'), findsOneWidget);
    // La sección Pago quedó bajo el fold — las secciones nuevas del
    // §037 (Observación + Entrega) la empujaron fuera del lazy build.
    await scrollToTappable(tester, find.text('Registrar pago'));
    expect(find.text('Registrar pago'), findsOneWidget);
  });

  testWidgets('pendiente recogida PRESENCIAL sin cobrar: primario '
      '"Registrar pago" + "Confirmar" DESHABILITADO con pista — la '
      'puerta §036 (la online pickup solo admite Nequi)', (
    tester,
  ) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);
    // adm-25 — received + presencial pickup + cash pendiente: la
    // recogida exige plata antes de entrar a cocina.
    await openDetail(tester, router, 'adm-25');

    // El avance real es cobrar: primario "Registrar pago" (el tonal de la
    // fila de pago se suprime — eco de composición §035).
    expect(find.text('Registrar pago'), findsOneWidget);

    // "Confirmar" presente pero bloqueado, con su pista — adelanta
    // la regla del backend (pickup sin pago → 409).
    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirmar'),
    );
    expect(confirmButton.onPressed, isNull);
    expect(find.text('Registra el pago primero'), findsOneWidget);
  });

  testWidgets('detalle Nequi pending: NINGÚN botón — ni avance, ni '
      'cobro manual, ni cancelar; la espera del webhook es literal '
      '(§036)', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);
    // Tomás — received + online pickup + Nequi pending.
    await openDetail(tester, router, 'adm-29');

    expect(
      find.text('Esperando confirmación de Nequi…'),
      findsOneWidget,
    );
    expect(find.text('Confirmar'), findsNothing);
    expect(find.text('Registrar pago'), findsNothing);
    expect(find.text('Cancelar pedido'), findsNothing);
  });

  testWidgets('detalle Nequi FALLIDO: solo "Cancelar pedido" — la '
      'única salida del cobro rechazado por el webhook (§036)', (
    tester,
  ) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);
    // Valeria — received + online pickup + Nequi failed.
    await openDetail(tester, router, 'adm-31');

    // La sección Entrega (+teléfono de la recogida) empujó la sección
    // Pago bajo el fold del lazy build — primero el método…
    await tester.scrollUntilVisible(
      find.text('Nequi'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // …se lee Nequi — no "Transf.".
    expect(find.text('Nequi'), findsWidgets);
    // …y luego el aviso (scrollear más abajo desmonta el de arriba).
    await tester.scrollUntilVisible(
      find.text('Nequi rechazó el pago — cancela el pedido'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Nequi rechazó el pago — cancela el pedido'),
      findsOneWidget,
    );
    expect(find.text('Confirmar'), findsNothing);
    expect(find.text('Registrar pago'), findsNothing);
    expect(find.text('Cancelar pedido'), findsOneWidget);
  });

  testWidgets('detalle Nequi PAGADO: flujo normal post-webhook — '
      '"Preparar" disponible (§036)', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);
    // Wanda — confirmed + online delivery + Nequi paid.
    await openDetail(tester, router, 'adm-32');

    expect(find.widgetWithText(FilledButton, 'Preparar'), findsOneWidget);
    expect(find.text('Esperando confirmación de Nequi…'), findsNothing);
    expect(find.text('Cancelar pedido'), findsOneWidget);
  });

  testWidgets('"Registrar pago" del detalle cobra el pedido ready y '
      'CIERRA de una — cobrar era el único bloqueo (§036)', (tester) async {
    final calls = stubToast(tester);
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);
    await openDetail(tester, router, 'adm-8');

    await tester.tap(find.text('Registrar pago').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final order = cubit.state.orderById('adm-8')!;
    expect(order.paymentStatus, OrderPaymentStatus.paid);
    // La mesa pagó y se fue: el pedido quedó done directo — la
    // pista y el "Entregado" desaparecen, acciones replegadas.
    expect(order.status, OrderStatus.done);
    expect(find.text('Registra el pago primero'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Entregado'), findsNothing);
    expect(calls.any((c) => c.arguments['msg'] == 'Pago confirmado'), isTrue);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('tras "Entregado" el detalle queda ABIERTO en terminal '
      '— acciones replegadas y chip Entregado (§036)', (tester) async {
    final calls = stubToast(tester);
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);
    // Beto — ready + pagado → el primario ya es "Entregado".
    await openDetail(tester, router, 'adm-3');
    await scrollToTappable(
      tester,
      find.widgetWithText(FilledButton, 'Entregado'),
    );

    await tester.tap(find.text('Entregado').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // La orden es done pero sigue en `active` (carril Entregado —
    // espera el cierre, §036) y el detalle la sigue mostrando.
    expect(cubit.state.orderById('adm-3')!.status, OrderStatus.done);
    expect(find.byType(AdminOrderDetailScreen), findsOneWidget);
    expect(find.text('Cancelar pedido'), findsNothing);
    expect(calls.any((c) => c.arguments['msg'] == 'Pedido entregado'), isTrue);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('cancelar exige confirmación: "No, dejarlo" no toca '
      'el pedido', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);
    await openDetail(tester, router, 'adm-1');
    await scrollToTappable(tester, find.text('Cancelar pedido'));

    await tester.tap(find.text('Cancelar pedido'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cancelar el pedido?'), findsOneWidget);

    await tester.tap(find.text('No, dejarlo'));
    await tester.pumpAndSettle();

    expect(cubit.state.orderById('adm-1')!.status, OrderStatus.received);
    // El detalle sigue abierto — nada se canceló.
    expect(find.byType(AdminOrderDetailScreen), findsOneWidget);
  });

  testWidgets('cancelar confirmado con motivo vacío: → cancelled al '
      'historial + toast + pop a la cola', (tester) async {
    final calls = stubToast(tester);
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);
    await openDetail(tester, router, 'adm-1');
    await scrollToTappable(tester, find.text('Cancelar pedido'));

    await tester.tap(find.text('Cancelar pedido'));
    await tester.pumpAndSettle();
    // Campo de motivo opcional presente — se confirma sin escribir.
    expect(find.text('Motivo (opcional)'), findsOneWidget);

    await tester.tap(find.text('Sí, cancelar'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final order = cubit.state.orderById('adm-1')!;
    expect(order.status, OrderStatus.cancelled);
    expect(order.cancelReason, isNull);
    expect(cubit.state.active.any((o) => o.id == 'adm-1'), isFalse);
    // Pop a la cola — la orden ya no existe para mirarla.
    expect(find.byType(AdminOrderDetailScreen), findsNothing);
    expect(find.text('COCINA'), findsOneWidget);
    expect(calls.any((c) => c.arguments['msg'] == 'Pedido cancelado'), isTrue);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('deep link /admin/:id SIN extra → redirect a /admin '
      '(patrón /orders/:id)', (tester) async {
    final router = buildAdminRouter();
    await pumpAdminApp(tester, router: router);
    await loadQueue(tester);

    router.go('${AuthGuard.adminRoute}/cualquier-id');
    await tester.pumpAndSettle();

    expect(find.byType(AdminOrderDetailScreen), findsNothing);
    expect(find.byType(AdminQueueScreen), findsOneWidget);
    expect(router.state.matchedLocation, AuthGuard.adminRoute);
  });

  group('detalle enriquecido (§037 — entrega, nota, armado y '
      'desglose)', () {
    testWidgets('domicilio: sección Entrega con etiqueta + referencia '
        '+ barrio + pin + celular, y el tap copia al portapapeles', (
      tester,
    ) async {
      final calls = stubToast(tester);
      final copied = stubClipboard(tester);
      final launches = stubUrlLauncher(tester);
      final router = buildAdminRouter();
      await pumpAdminApp(tester, router: router);
      await loadQueue(tester);
      // adm-1 — online delivery transfer pendiente con todo el bloque
      // de entrega sembrado (Casa / referencia / barrio / pin / 300…).
      await openDetail(tester, router, 'adm-1');

      await tester.scrollUntilVisible(
        find.text('Recibe: 300 123 4567'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Entrega'), findsOneWidget);
      expect(find.text('Casa'), findsOneWidget);
      expect(
        find.text('Portón negro frente a la cancha'),
        findsOneWidget,
      );
      expect(find.text('Barrio La Esperanza'), findsOneWidget);
      expect(find.text('Con ubicación de Google'), findsOneWidget);
      expect(find.text('Recibe: 300 123 4567'), findsOneWidget);

      // Tap en la fila del celular → portapapeles + toast (§037 —
      // la zona no siempre tiene dirección formal, el teléfono es
      // el plan B para sacar el domicilio).
      await tester.tap(find.text('Recibe: 300 123 4567'));
      await tester.pumpAndSettle();
      expect(copied, ['3001234567']);
      expect(
        calls.any((c) => c.arguments['msg'] == 'Teléfono copiado'),
        isTrue,
      );

      // Tap en la fila del pin → abre Maps con el punto del cliente
      // (el dueño navega al domicilio, §037); el ícono copia el
      // enlace para compartirlo por WhatsApp si hace falta.
      const mapsLink = 'https://maps.app.goo.gl/s5RiFni6LsV4Ptmj9';
      await tester.scrollUntilVisible(
        find.text('Con ubicación de Google'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Con ubicación de Google'));
      await tester.pumpAndSettle();
      expect(
        launches.any((c) => c.arguments['url'] == mapsLink),
        isTrue,
      );
      await tester.tap(find.byTooltip('Copiar ubicación'));
      await tester.pumpAndSettle();
      expect(copied, contains(mapsLink));
      expect(
        calls.any((c) => c.arguments['msg'] == 'Ubicación copiada'),
        isTrue,
      );

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('pickup: la sección dice "Lo recogen en el local" y '
        'la nota del cliente viaja arriba de los ítems', (tester) async {
      final router = buildAdminRouter();
      await pumpAdminApp(tester, router: router);
      await loadQueue(tester);
      // adm-21 — online pickup Nequi pagado con nota "La recoge mi
      // hermano".
      await openDetail(tester, router, 'adm-21');

      // Observación justo bajo "Pedido" — instrucción de cocina, va
      // antes que los ítems (decisión §037).
      expect(find.text('Observación'), findsOneWidget);
      expect(find.text('La recoge mi hermano'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Lo recogen en el local'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Entrega'), findsOneWidget);
      expect(find.text('Lo recogen en el local'), findsOneWidget);
      // La recogida SÍ muestra el celular del cliente — si nadie
      // viene por el pedido, el dueño tiene a quién llamar (§037).
      expect(find.text('Recibe: 320 456 7890'), findsOneWidget);
    });

    testWidgets('dineIn: sin sección Entrega ni Observación — la mesa '
        'ya sale en el header', (tester) async {
      final router = buildAdminRouter();
      await pumpAdminApp(tester, router: router);
      await loadQueue(tester);
      // adm-2 — Mesa 3, dineIn sin nota.
      await openDetail(tester, router, 'adm-2');

      expect(find.text('En el local · Mesa 3'), findsOneWidget);
      // Recorre el detalle completo (el ListView construye perezoso).
      await tester.scrollUntilVisible(
        find.text('Pago'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Entrega'), findsNothing);
      expect(find.text('Lo recogen en el local'), findsNothing);
      expect(find.text('Observación'), findsNothing);
      expect(find.text('Domicilio'), findsNothing);
    });

    testWidgets('ítem con modificadores nace DESPLEGADO — "Cebolla" '
        'en quitados y el extra con su +\$2.500 sin tocar nada; el '
        'ítem con solo incluidos espera el chip "Detalle"', (
      tester,
    ) async {
      final router = buildAdminRouter();
      await pumpAdminApp(tester, router: router);
      await loadQueue(tester);
      await openDetail(tester, router, 'adm-1');

      // Auto-expandido SIN tap — "sin cebolla" es instrucción de
      // cocina y no puede depender de que el dueño toque (§037).
      await tester.scrollUntilVisible(
        find.text('Cebolla'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Se le quitó'), findsOneWidget);
      expect(find.text('Cebolla'), findsOneWidget);
      expect(
        find.text(r'Queso cheddar +$2.500', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Piña'), findsOneWidget);
      // El Depredador también muestra su snapshot de incluidos.
      expect(find.text('Ingredientes'), findsOneWidget);
      expect(find.text('Pan artesanal'), findsOneWidget);

      // Las papas solo traen incluidos → nacen colapsadas y el chip
      // las abre (el perro estándar con snapshot espera el toque).
      expect(find.text('Papas criollas'), findsNothing);
      await scrollToTappable(tester, find.text('Detalle').last);
      await tester.tap(find.text('Detalle').last);
      await tester.pumpAndSettle();
      expect(find.text('Papas criollas'), findsOneWidget);
    });

    testWidgets('el perro estándar NO gasta chip — sin modificadores '
        'ni incluidos no hay nada que desplegar', (tester) async {
      final router = buildAdminRouter();
      await pumpAdminApp(tester, router: router);
      await loadQueue(tester);
      // adm-2 — Mesa 3: un solo El Cachorro pelado.
      await openDetail(tester, router, 'adm-2');

      await tester.scrollUntilVisible(
        find.text('1× El Cachorro'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('1× El Cachorro'), findsOneWidget);
      expect(find.text('Detalle'), findsNothing);
    });

    testWidgets('desglose del cobro: Subtotal + Domicilio + Total '
        'separados — el fee se ve en su fila (§037)', (tester) async {
      final router = buildAdminRouter();
      await pumpAdminApp(tester, router: router);
      await loadQueue(tester);
      await openDetail(tester, router, 'adm-1');

      await tester.scrollUntilVisible(
        find.text('Subtotal'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Subtotal'), findsOneWidget);
      // El chip de servicio del header también dice "Domicilio" —
      // solo se exige que la fila exista, no su conteo.
      expect(find.text('Domicilio'), findsWidgets);
      expect(find.text(r'$56.000'), findsOneWidget);
      expect(find.text(r'$5.000'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text(r'$61.000'), findsOneWidget);
    });
  });
}
