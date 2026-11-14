import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_queue_cubit.dart';
import 'package:depredadog_app/features/admin/presentation/screens/admin_queue_screen.dart';
import 'package:depredadog_app/features/admin/presentation/widgets/admin_lane_strip.dart';
import 'package:depredadog_app/features/admin/presentation/widgets/admin_order_card.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';
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
    // Cubit REAL con los mocks de fábrica (16 activos — todos los
    // carriles con todos los casos + 3 cancelados en el historial).
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
  /// La superficie se estira a 1600px: los carriles cargan hasta 4
  /// cards y el ListView solo construye las visibles — sin alto
  /// extra los finds no ven la card de abajo.
  Future<void> pumpQueue(WidgetTester tester, {Key? key}) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
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
  }

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

  testWidgets('primera carga: spinner + header fijo (botón cierre, '
      'título Cocina, ícono historial)', (tester) async {
    // Sin load() — el estado inicial de la fábrica ya es cargando.
    await pumpQueue(tester);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('COCINA'), findsOneWidget);
    expect(find.byIcon(Icons.point_of_sale_rounded), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
  });

  testWidgets('kanban: strip de 5 carriles con contadores y una sola '
      'card por página (§036)', (tester) async {
    await pumpQueue(tester);
    await loadQueue(tester);

    // Header fijo: ícono de caja + badge de notificación (3 done
    // sin cerrar: adm-5, adm-16, adm-17) + título + historial.
    expect(find.byIcon(Icons.point_of_sale_rounded), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('3')),
      findsOneWidget,
    );
    expect(find.text('COCINA'), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);

    // Strip: 5 chips de carril — y NADA más: la card no repite su
    // estado (el carril ya lo dice — decisión del dueño §036).
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Confirmado'), findsOneWidget);
    expect(find.text('En la plancha'), findsOneWidget);
    expect(find.text('Listo'), findsOneWidget);
    expect(find.text('Entregado'), findsOneWidget);
    // Contadores de carril (13, 7, 3, 4, 3) + el '3' del badge —
    // Pendiente lleva TODAS las variantes de la puerta de pago +
    // la contraentrega + los Nequi en espera del webhook; el
    // presencial dineIn/delivery nace Confirmado (§036).
    expect(find.text('13'), findsOneWidget);
    expect(find.text('7'), findsOneWidget); // Confirmado
    expect(find.text('3'), findsNWidgets(3)); // 2 chips + badge
    expect(find.text('4'), findsOneWidget); // Listo

    // Carril inicial = Pendiente (FIFO — el que más espera arriba).
    // El ListView es lazy: solo las primeras cards se construyen.
    expect(find.byType(AdminOrderCard), findsWidgets);
    expect(find.text('Ana Uno'), findsOneWidget);
    expect(find.text('Mario Doce'), findsOneWidget);
    expect(find.text('Nora Trece'), findsOneWidget);
    expect(find.text('2× El Depredador, 1× Manada de papas'), findsOneWidget);
    expect(find.text('\$61.000'), findsOneWidget);
    expect(find.text('hace 12 min'), findsOneWidget);
    // El chip de la card es el de SERVICIO (decisión del dueño):
    // El chip de la card es el SERVICIO: Pendiente solo muestra
    // Domicilio/Recogida — Mesa NUNCA pisa este carril porque el
    // presencial dineIn nace Confirmado (§036). El canal vive en
    // la esquina como susurro — "Online" se lee a la derecha.
    expect(find.text('Domicilio'), findsWidgets);
    expect(find.text('Recogida'), findsWidgets);
    expect(find.text('Mesa'), findsNothing);
    expect(find.text('Online'), findsWidgets);
    // Los visibles son todos confirmables — las bloqueadas quedan
    // más abajo en el FIFO (test dedicado con scroll).
    expect(find.text('Confirmar'), findsWidgets);

    // FAB del CTA del dueño — ícono solo, el label vive en el
    // tooltip (decisión del dueño: el texto sobraba).
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byTooltip('Nueva orden'), findsOneWidget);
  });

  testWidgets('tap en chip del strip salta al carril — Listo muestra '
      'Registrar pago (sin cobrar) + Entregado (pagado)', (tester) async {
    await pumpQueue(tester);
    await loadQueue(tester);

    // El strip arranca en la zona negra — en superficie de test
    // (800×600) 'Listo' nace fuera del viewport: ensureVisible lo
    // trae al scroll antes del tap (como haría el ensureVisible
    // del carril activo en producción).
    await tester.ensureVisible(find.text('Listo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();

    // Carril Listo: 4 cards — Mesa 1, Beto Dos e Inés Nueve ya
    // pagados ("Entregado"), Mesa 7 sin cobrar ("Registrar pago") — las
    // dos caras de la puerta del pago (§036).
    expect(find.byType(AdminOrderCard), findsNWidgets(4));
    expect(find.text('En el local · Mesa 1'), findsOneWidget);
    expect(find.text('Beto Dos'), findsOneWidget);
    expect(find.text('Inés Nueve'), findsOneWidget);
    expect(find.text('En el local · Mesa 7'), findsOneWidget);
    // "Registrar pago" solo aparece cuando el cobro bloquea el Entregado;
    // los 3 pagados ya listan su "Entregado" (acotado a las cards —
    // el chip del strip también se llama así).
    expect(find.text('Registrar pago'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AdminOrderCard),
        matching: find.text('Entregado'),
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('swipe entre carriles y labels de acción por canal '
      '(§036)', (tester) async {
    await pumpQueue(tester);
    await loadQueue(tester);

    // Swipe izquierdo → carril Confirmado (7 cards — lazy):
    // Mesa 3, mostrador, Felipe Seis (online pagado) y Wanda
    // (Nequi pagado — el webhook ya habló) arriba; abajo las 3
    // presenciales que NACEN confirmadas (§036: Óscar domicilio
    // por teléfono + Mesa 4 + Mesa 6) — todos con "Preparar".
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(AdminOrderCard), findsWidgets);
    expect(find.text('En el local · Mesa 3'), findsOneWidget);
    expect(find.text('Felipe Seis'), findsOneWidget);
    expect(find.text('Preparar'), findsWidgets);
    expect(find.text('Registrar pago'), findsNothing);
    // Scroll al fondo del carril — las confirmadas de nacimiento.
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Óscar Catorce'), findsOneWidget);
    expect(find.text('En el local · Mesa 4'), findsOneWidget);
    expect(find.text('En el local · Mesa 6'), findsOneWidget);

    // Segundo swipe → carril Preparando: un pedido por canal —
    // Mesa 5 dine_in "Servir", Héctor delivery "Va en camino",
    // Gabriel pickup "Listo p/recoger" (labels del paso, §036).
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(AdminOrderCard), findsNWidgets(3));
    expect(find.text('En el local · Mesa 5'), findsOneWidget);
    expect(find.text('Héctor Ocho'), findsOneWidget);
    expect(find.text('Gabriel Siete'), findsOneWidget);
    expect(find.text('Servir'), findsOneWidget);
    expect(find.text('Va en camino'), findsOneWidget);
    expect(find.text('Listo p/recoger'), findsOneWidget);

    // Tercer swipe → Listo; cuarto → Entregado (3 terminales sin
    // acción — esperan el cierre de caja: Mesa 9, Carla, Jorge).
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(AdminOrderCard), findsNWidgets(3));
    expect(find.text('En el local · Mesa 9'), findsOneWidget);
    expect(find.text('Carla Tres'), findsOneWidget);
    expect(find.text('Jorge Diez'), findsOneWidget);
    expect(find.text('Cancelar pedido'), findsNothing);
    // Terminal no tiene botón de acción en la card (el "Cerrar
    // caja" del header es FilledButton y vive fuera de la card).
    expect(
      find.descendant(
        of: find.byType(AdminOrderCard),
        matching: find.byType(FilledButton),
      ),
      findsNothing,
    );
  });

  testWidgets('vacío global: "Sin pedidos activos" cuando TODOS los '
      'carriles están vacíos', (tester) async {
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
    // El strip SE OCULTA sin tablero — chips "0" que no hacen nada
    // serían affordance falsa (revisor-ui §036).
    expect(find.byType(AdminLaneStrip), findsNothing);
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

    // Reintento con el canal ya sano → el tablero aparece. Pumps
    // fijos: mientras el spinner de recarga anima NO se puede
    // pumpAndSettle.
    failing.fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byType(AdminOrderCard), findsWidgets);
    expect(find.text('Ana Uno'), findsOneWidget);
  });

  testWidgets('error con datos: fila inline conserva el tablero '
      '(revisor-ui §034)', (tester) async {
    await cubit.close();
    await locator.reset();
    cubit = _StaleErrorQueueCubit();
    locator.registerSingleton<AdminQueueCubit>(cubit);

    await pumpQueue(tester);
    await loadQueue(tester);

    // El kanban queda pintado + la fila inline — no página de error.
    expect(cubit.state.active, hasLength(30));
    expect(find.byType(AdminOrderCard), findsWidgets);
    expect(find.text('No pudimos cargar la cola'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    expect(find.text('Ana Uno'), findsOneWidget);
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

    // Pull-down sobre el ListView del carril visible — la misma
    // distancia/velocidad del test de orders (§027).
    await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
    // El load mock tiene 400ms de latencia simulada — pump fijo
    // mientras el RefreshIndicator anima.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(counting.loads, 2);
  });

  testWidgets('puerta de la recogida PRESENCIAL: sin cobrar la acción '
      'es "Registrar pago" — la online solo acepta Nequi (§036)', (
    tester,
  ) async {
    await pumpQueue(tester);
    await loadQueue(tester);

    // Las recogidas presenciales sin cobrar son las ÚLTIMAS del FIFO
    // (mostrador cash + teléfono transfer — 4 y 1 min): drag al
    // fondo del ListView del carril para construirlas.
    final laneList = find.byType(ListView);
    for (var i = 0; i < 8; i++) {
      await tester.drag(laneList, const Offset(0, -400));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // "Registrar pago" en vez de "Confirmar" solo en las 2
    // presenciales — la recogida ONLINE quedó congelada al Nequi
    // (efectivo/transfer ya no existen ahí: producción protegida).
    expect(find.text('Registrar pago'), findsNWidgets(2));

    // Cobrar la primera (adm-25, mostrador cash): su card pasa a
    // "Confirmar" sin salir del carril — el toast confirma el cobro.
    await tester.tap(find.text('Registrar pago').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Cobrar era el único bloqueo — adm-25 cruzó a Confirmado en
    // el mismo toque (§036); queda la del teléfono sin cobrar.
    expect(
      cubit.state.orderById('adm-25')!.paymentStatus,
      OrderPaymentStatus.paid,
    );
    expect(
      cubit.state.orderById('adm-25')!.status,
      OrderStatus.confirmed,
    );
    expect(find.text('Registrar pago'), findsOneWidget);
  });

  testWidgets('cobro Nequi congelado: rótulo de espera SIN botones '
      '— el webhook manda, no el dueño (§036)', (tester) async {
    await pumpQueue(tester);
    await loadQueue(tester);

    // Helper local: la card de [name] lleva el rótulo [hint] en el
    // slot del botón y NADA tappeable (ni Confirmar ni Registrar
    // pago — nadie adelanta lo que solo el webhook confirma). El
    // drag-loop construye las cards lazy del ListView del carril.
    Future<void> expectFrozen(String name, String hint) async {
      for (var i = 0; i < 12 && find.text(name).evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -350));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final card = find.ancestor(
        of: find.text(name),
        matching: find.byType(AdminOrderCard),
      );
      expect(find.descendant(of: card, matching: find.text(hint)),
          findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.byType(FilledButton)),
        findsNothing,
      );
    }

    const waiting = 'Esperando confirmación de Nequi…';
    const rejected = 'Nequi rechazó el pago — cancela el pedido';

    // TODA recogida online es Nequi: Sara era transfer, ahora
    // espera el webhook igual que Tomás y Uriel (delivery).
    await expectFrozen('Tomás Veintinueve', waiting);
    await expectFrozen('Sara Quince', waiting);
    await expectFrozen('Uriel Treinta', waiting);

    // Los rechazados solo se cancelan (en el detalle): Valeria y
    // Daniela — la migrada, antes "pago fallido" cobrable a mano.
    await expectFrozen('Valeria Treintaiuno', rejected);
    await expectFrozen('Daniela Cuatro', rejected);
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

  testWidgets('tap en "Confirmar" mueve la card al carril Confirmado '
      'y el contador del chip cambia — sin navegar (§036)', (tester) async {
    final calls = stubToast(tester);
    await pumpQueue(tester);
    await loadQueue(tester);

    // Ana Uno (received) es la primera card del carril Pendiente
    // (FIFO — la que más espera) → su "Confirmar" es el .first.
    await tester.tap(find.text('Confirmar').first);
    // Spinner inline mientras el mock corre (~400ms).
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    // El carril Pendiente conserva sus cards — el kanban no se
    // vacía por un solo avance (quedan 12 pendientes).
    expect(find.text('Sin pedidos'), findsNothing);
    expect(find.byType(AdminOrderCard), findsWidgets);
    expect(cubit.state.orderById('adm-1')!.status, OrderStatus.confirmed);
    // El contador del chip Confirmado subió a 8; el '4' que queda
    // es solo el de Listo.
    expect(find.text('8'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(calls.any((c) => c.arguments['msg'] == 'Pedido confirmado'), isTrue);

    // En el carril Confirmado la card ya está — Ana se suma a las
    // 7 (los presenciales nacen confirmados, §036); el ListView es
    // lazy así que se verifica la presencia, no el conteo.
    await tester.tap(find.text('Confirmado'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminOrderCard), findsWidgets);
    expect(find.text('Ana Uno'), findsOneWidget);
    expect(find.text('Preparar'), findsWidgets);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('header dentro del scroll: colapsa con el carril, el '
      'strip queda fijado y la flecha vuelve al inicio (§036)', (
    tester,
  ) async {
    await pumpQueue(tester);
    await loadQueue(tester);

    // Header abierto al inicio — caja + título + historial visibles;
    // la flecha no existe sin scroll profundo.
    expect(find.byIcon(Icons.point_of_sale_rounded), findsOneWidget);
    expect(find.text('COCINA'), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);

    // Scroll profundo del carril (4×400px > el umbral ~2 cards).
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // El header colapsó — el ícono de caja se desmontó del sliver o
    // quedó sobre el viewport; el strip de carriles SIGUE fijado.
    final closeIcon = find.byIcon(Icons.point_of_sale_rounded);
    final headerHidden = closeIcon.evaluate().isEmpty ||
        tester.getTopLeft(closeIcon).dy < 0;
    expect(headerHidden, isTrue);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Confirmado'), findsOneWidget);
    // La flecha apareció sobre el FAB de nueva orden.
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

    // Tap → carril de vuelta al inicio + header reabierto + la
    // flecha se retira sola (el scroll de regreso la desactiva).
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.point_of_sale_rounded), findsOneWidget);
    expect(find.text('COCINA'), findsOneWidget);
    expect(find.text('Ana Uno'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
  });
}
