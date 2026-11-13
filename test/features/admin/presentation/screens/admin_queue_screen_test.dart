import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_queue_cubit.dart';
import 'package:depredadog_app/features/admin/presentation/screens/admin_queue_screen.dart';
import 'package:depredadog_app/features/admin/presentation/widgets/admin_order_card.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

/// Cola que falla la primera carga — la fase mock no puede fallar de
/// verdad, así que se emite el flag failed para ejercer la rama de
/// error + reintento (la forma del estado ya es la de integración).
class _FailingQueueCubit extends AdminQueueCubit {
  bool fail = true;

  @override
  Future<void> load() async {
    if (fail) {
      emit(state.copyWith(dataLoading: false, failed: true));
      return;
    }
    await super.load();
  }
}

/// Cola que cuenta sus loads — para verificar que el pull-to-refresh
/// re-consulta (paridad Pedidos §027).
class _CountingQueueCubit extends AdminQueueCubit {
  int loads = 0;

  @override
  Future<void> load() async {
    loads++;
    await super.load();
  }
}

/// Cola que falla el REFRESH con datos ya cargados — ejerce la rama
/// de error inline que preserva las cards pintadas (revisor-ui §034:
/// perder la cola visible por un fallo transitorio es peor que datos
/// algo viejos + retry).
class _StaleErrorQueueCubit extends AdminQueueCubit {
  @override
  Future<void> load() async {
    await super.load();
    emit(state.copyWith(failed: true));
  }
}

void main() {
  final locator = GetIt.instance;
  late AdminQueueCubit cubit;

  setUp(() {
    // Cubit REAL con los mocks de fábrica (4 activos + 2 historial —
    // cubren online/presencial, mesa/mostrador y los 3 estados vivos).
    cubit = AdminQueueCubit();
    locator.registerSingleton<AdminQueueCubit>(cubit);
  });

  tearDown(() async {
    await cubit.close();
    await locator.reset();
  });

  /// Intercepta el canal de fluttertoast — no pinta en el árbol de
  /// widgets; el assert verifica el mensaje real (patrón del shell).
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

  /// Harness: MaterialApp con tema oscuro fijo + l10n — la pantalla
  /// resuelve su cubit por locator como en producción. La Key es para
  /// re-pumps dentro del mismo test: sin ella, un segundo pumpWidget
  /// con el mismo widget const salta el update (Element.updateChild
  /// por identidad) y la pantalla queda atada al cubit anterior.
  Future<void> pumpQueue(WidgetTester tester, {Key? key}) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: AdminQueueScreen(key: key),
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

  /// Lanza load() y lo deja terminar: el delay simulado de 400ms vive
  /// en el fake-async del binding (un `await` desnudo colgaría el
  /// test) — vence con un pump de 500ms. Seguro llamarlo antes o
  /// después de pumpQueue.
  Future<void> loadQueue(WidgetTester tester) async {
    final load = cubit.load();
    await tester.pump(const Duration(milliseconds: 500));
    await load;
    await tester.pumpAndSettle();
  }

  testWidgets('primera carga: spinner + título Cocina (dataLoading '
      'arranca en true)', (tester) async {
    // Sin load() — el estado inicial de la fábrica ya es cargando.
    await pumpQueue(tester);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('COCINA'), findsOneWidget);
  });

  testWidgets('cola activa: cards con canal, cliente/mesa, ítems, '
      'pago, estado, total y "hace N min"', (tester) async {
    await pumpQueue(tester);
    await loadQueue(tester);

    // Título scrolling + filtro segmentado.
    expect(find.text('COCINA'), findsOneWidget);
    expect(find.text('Activos'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);

    // Las 5 cards del bucket activo (la 5ª — la orden grande de
    // Mesa 5 — queda bajo el fold del viewport del test).
    expect(find.byType(AdminOrderCard), findsAtLeastNWidgets(4));

    // Canales (2 online + 2 presencial).
    expect(find.text('Online'), findsNWidgets(2));
    expect(find.text('Presencial'), findsNWidgets(2));

    // Clientes online con nombre / presencial mesa / mostrador.
    expect(find.text('Ana Uno'), findsOneWidget);
    expect(find.text('Beto Dos'), findsOneWidget);
    expect(find.text('En el local'), findsOneWidget);

    // Resumen de ítems y totales (los visibles sobre el fold).
    expect(find.text('2× El Depredador, 1× Manada de papas'), findsOneWidget);
    expect(find.text('\$56.000'), findsOneWidget);
    expect(find.text('\$34.000'), findsOneWidget);

    // Chips de estado del pedido (Pendiente = received, Confirmado,
    // En la plancha) y de pago (Efectivo/Transf. + Pagado/Pago
    // pendiente). Mínimos — cuántos quepan en el fold depende del
    // viewport, no del contenido.
    expect(find.text('Pendiente'), findsNWidgets(2));
    expect(find.text('Confirmado'), findsAtLeastNWidgets(1));
    expect(find.text('En la plancha'), findsOneWidget);
    expect(find.text('Efectivo'), findsAtLeastNWidgets(2));
    expect(find.text('Transf.'), findsNWidgets(2));
    expect(find.text('Pagado'), findsAtLeastNWidgets(2));
    expect(find.text('Pago pendiente'), findsAtLeastNWidgets(1));

    // Frescura — "hace 12 min" del más viejo, "hace 1 min" del recién
    // caído.
    expect(find.text('hace 12 min'), findsOneWidget);
    expect(find.text('hace 1 min'), findsOneWidget);

    // FAB del CTA del dueño.
    expect(find.text('Nueva orden'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Las dos mesas quedaron bajo el fold — aparecen con scroll;
    // la orden grande de Mesa 5 (1× de cada ítem del menú — 7
    // líneas) con su resumen truncado.
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('En el local · Mesa 3'), findsOneWidget);
    expect(find.text('En el local · Mesa 5'), findsOneWidget);
    expect(find.text('\$14.000'), findsOneWidget);
    expect(find.text('\$118.000'), findsOneWidget);
    // maxLines 2 del resumen: las primeras líneas visibles + el
    // sufijo "+N más" que cuenta lo que no cupo (decisión §034 —
    // la orden de 7 ítems no puede leerse como una de 2).
    expect(
      find.textContaining('El Depredador', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining(RegExp(r'\+\d+ más'), findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('filtro Historial: swappea a terminados/cancelados', (
    tester,
  ) async {
    await pumpQueue(tester);
    await loadQueue(tester);

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminOrderCard), findsNWidgets(2));
    expect(find.text('Carla Tres'), findsOneWidget);
    expect(find.text('En el local · Mesa 2'), findsOneWidget);
    expect(find.text('Listo'), findsOneWidget);
    expect(find.text('Cancelado'), findsOneWidget);
    expect(find.text('hace 3 h'), findsOneWidget);
    // Los activos quedaron fuera del segmento visible.
    expect(find.text('Ana Uno'), findsNothing);
  });

  testWidgets('vacío por bucket: "Sin pedidos activos" y "Historial '
      'vacío" según el segmento', (tester) async {
    await cubit.close();
    await locator.reset();
    cubit = AdminQueueCubit(mockActive: const [], mockHistory: const []);
    locator.registerSingleton<AdminQueueCubit>(cubit);

    await pumpQueue(tester);
    await loadQueue(tester);

    expect(find.text('Sin pedidos activos'), findsOneWidget);
    expect(
      find.text('La cocina descansa — los pedidos nuevos caen aquí solos.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('Historial vacío'), findsOneWidget);
    expect(find.byType(AdminOrderCard), findsNothing);
  });

  testWidgets('error sin datos: mensaje + Reintentar recarga la cola', (
    tester,
  ) async {
    await cubit.close();
    await locator.reset();
    final failing = _FailingQueueCubit();
    cubit = failing;
    locator.registerSingleton<AdminQueueCubit>(failing);

    await pumpQueue(tester);
    await loadQueue(tester);

    expect(find.text('No pudimos cargar la cola'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(AdminOrderCard), findsNothing);

    // Reintento con el canal ya sano → la cola aparece. Pumps fijos:
    // mientras el spinner de recarga anima NO se puede pumpAndSettle.
    failing.fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byType(AdminOrderCard), findsAtLeastNWidgets(4));
    expect(find.text('Ana Uno'), findsOneWidget);
  });

  testWidgets('error con datos: fila inline conserva las cards y '
      'queda ACOTADA a la zona negra (§034c)', (tester) async {
    await cubit.close();
    await locator.reset();
    cubit = _StaleErrorQueueCubit();
    locator.registerSingleton<AdminQueueCubit>(cubit);

    await pumpQueue(tester);
    await loadQueue(tester);

    // La cola queda pintada + la fila inline encima — no página de
    // error. Las 5 del bucket siguen en el estado; en el viewport de
    // 800×600 entran 3 (la fila empujó la lista — el resto abajo).
    expect(cubit.state.active, hasLength(5));
    expect(find.byType(AdminOrderCard), findsAtLeastNWidgets(3));
    expect(find.text('No pudimos cargar la cola'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);

    // Geometría de la zona negra (tester = 800×600 → franja [0,320],
    // cards [160, 684]): la fila usa los márgenes de las cards —
    // ni el ícono pinta sobre mostaza ni el botón sobrepasa el
    // margen derecho del conjunto.
    final iconLeft = tester.getTopLeft(find.byIcon(Icons.cloud_off_rounded));
    expect(iconLeft.dx, greaterThanOrEqualTo(160));
    final retryRight = tester.getTopRight(find.text('Reintentar'));
    expect(retryRight.dx, lessThanOrEqualTo(684));

    // La 4ª card sobrevivió — aparece al hacer scroll.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('En el local · Mesa 3'), findsOneWidget);
  });

  testWidgets('vacío y error sin datos se CENTRAN en la zona negra, '
      'no en el ancho completo (§034c)', (tester) async {
    // Bucket vacío → _QueueEmpty.
    await cubit.close();
    await locator.reset();
    cubit = AdminQueueCubit(mockActive: const [], mockHistory: const []);
    locator.registerSingleton<AdminQueueCubit>(cubit);

    await pumpQueue(tester);
    await loadQueue(tester);

    // Eje de la zona negra: [320, 800] → 560 (la franja es el 40%
    // de los 800 lógicos del tester). Sin el Padding el eje cae en
    // 400 y el texto cruza el filo mostaza/negro.
    expect(
      tester.getCenter(find.text('Sin pedidos activos')).dx,
      closeTo(560, 15),
    );

    // Error sin datos → _QueueError, mismo eje. La Key fuerza un
    // elemento nuevo: con el widget idéntico el segundo pump no
    // reconstruye y la pantalla queda escuchando el cubit cerrado.
    await cubit.close();
    await locator.reset();
    cubit = _FailingQueueCubit();
    locator.registerSingleton<AdminQueueCubit>(cubit);

    await pumpQueue(tester, key: UniqueKey());
    await loadQueue(tester);

    expect(
      tester.getCenter(find.text('No pudimos cargar la cola')).dx,
      closeTo(560, 15),
    );
  });

  testWidgets('pull-to-refresh re-consulta la cola (paridad Pedidos '
      '§027)', (tester) async {
    await cubit.close();
    await locator.reset();
    final counting = _CountingQueueCubit();
    cubit = counting;
    locator.registerSingleton<AdminQueueCubit>(counting);

    await pumpQueue(tester);
    await loadQueue(tester);
    expect(counting.loads, 1);

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump();
    // El load mock tiene 400ms de latencia simulada — pump fijo
    // mientras el RefreshIndicator anima.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(counting.loads, 2);
  });

  testWidgets('FAB "Nueva orden" → toast "Disponible próximamente" '
      '(form en el ciclo 3)', (tester) async {
    final calls = stubToast(tester);
    await pumpQueue(tester);
    await loadQueue(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.first.method, 'showToast');
    expect(calls.first.arguments['msg'], 'Disponible próximamente');

    // Expira el Future.delayed interno de fluttertoast.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('tap en card → toast del detalle (ciclo 2)', (tester) async {
    final calls = stubToast(tester);
    await pumpQueue(tester);
    await loadQueue(tester);

    await tester.tap(find.byType(AdminOrderCard).first);
    await tester.pump();

    expect(calls, hasLength(1));
    expect(
      calls.first.arguments['msg'],
      'El detalle llega en el próximo ciclo',
    );

    await tester.pump(const Duration(seconds: 2));
  });
}
