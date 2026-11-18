import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_day_close.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/domain/failures/admin_failure.dart';
import 'package:depredadog_app/features/admin/domain/repositories/i_admin_repository.dart';
import 'package:depredadog_app/features/admin/domain/use_cases/load_admin_queue_use_case.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_queue_cubit.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_queue_state.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';

import '../../fixtures/admin_order_fixtures.dart';

AdminOrder _order(
  String id,
  OrderStatus status,
  DateTime placedAt, {
  AdminServiceType serviceType = AdminServiceType.delivery,
  AdminPaymentMethod method = AdminPaymentMethod.cash,
  OrderPaymentStatus payment = OrderPaymentStatus.paid,
}) => AdminOrder(
  id: id,
  channel: AdminOrderChannel.online,
  serviceType: serviceType,
  status: status,
  items: const [],
  paymentMethod: method,
  paymentStatus: payment,
  subtotal: 10000,
  deliveryFee: 0,
  placedAt: placedAt,
);

void main() {
  group('AdminQueueCubit (§038 — cola real via LoadAdminQueueUseCase)', () {
    test('estado inicial: cargando, bandejas vacías, sin preview de '
        'cierre ni busy', () {
      final cubit = buildAdminQueueCubit();
      addTearDown(cubit.close);

      expect(cubit.state.dataLoading, isTrue);
      expect(cubit.state.failed, isFalse);
      expect(cubit.state.active, isEmpty);
      expect(cubit.state.history, isEmpty);
      expect(cubit.state.dayClose, isNull);
      expect(cubit.state.dayCloseBusy, isFalse);
      expect(cubit.state.deliveredCount, 0);
    });

    blocTest<AdminQueueCubit, AdminQueueState>(
      'load(): emite cargando → activos → historial (30 activos + 3 '
      'de fixtures — todas las variantes de la puerta de pago)',
      build: buildAdminQueueCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AdminQueueState>()
            .having((s) => s.dataLoading, 'dataLoading', isTrue)
            .having((s) => s.failed, 'failed', isFalse),
        isA<AdminQueueState>()
            .having((s) => s.active.length, 'active', 30)
            .having((s) => s.dataLoading, 'dataLoading', isFalse)
            .having((s) => s.failed, 'failed', isFalse),
        isA<AdminQueueState>()
            .having((s) => s.history.length, 'history', 3),
      ],
    );

    test('load(): falla del bucket activo SIN datos previos → '
        'failed:true (vista de error completa)', () async {
      final cubit = buildAdminQueueCubit(
        activeFailure: const AdminOfflineFailure(),
        historyFailure: const AdminOfflineFailure(),
      );
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.failed, isTrue);
      expect(cubit.state.dataLoading, isFalse);
      expect(cubit.state.active, isEmpty);
      expect(cubit.state.history, isEmpty);
    });

    test('load(): falla activa en refresh → failed:true CONSERVANDO '
        'la cola pintada (banner sobre datos stale)', () async {
      // Primer load sano, luego el servidor cae — pull-to-refresh.
      final useCase = FakeLoadAdminQueueUseCase();
      when(useCase.call).thenAnswer(
        (_) async => AdminQueueData(
          active: Right(adminActiveFixtures()),
          history: Right(
            AdminHistoryPage(
              items: adminHistoryFixtures(),
              total: adminHistoryFixtures().length,
            ),
          ),
        ),
      );
      final detail = FakeGetAdminOrderDetailUseCase();
      when(
        () => detail.call(any()),
      ).thenAnswer((_) async => const Left(AdminServerFailure('stub')));
      final cubit = AdminQueueCubit(
        loadQueue: useCase,
        getOrderDetail: detail,
        updateOrderStatus: FakeUpdateAdminOrderStatusUseCase(),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.active, hasLength(30));

      when(useCase.call).thenAnswer(
        (_) async => const AdminQueueData(
          active: Left(AdminServerFailure('boom')),
          history: Left(AdminServerFailure('boom')),
        ),
      );
      await cubit.load();

      expect(cubit.state.failed, isTrue);
      expect(cubit.state.dataLoading, isFalse);
      // La bandeja NO se vació — el error viaja sobre los datos
      // viejos (revisor-ui §034).
      expect(cubit.state.active, hasLength(30));
      expect(cubit.state.history, hasLength(3));
    });

    test('load(): falla SOLO el historial → la cola carga igual y '
        'history conserva en silencio (sin superficie visual hoy)', () async {
      final cubit = buildAdminQueueCubit(
        historyFailure: const AdminServerFailure('boom'),
      );
      addTearDown(cubit.close);
      await cubit.load();

      expect(cubit.state.failed, isFalse);
      expect(cubit.state.active, hasLength(30));
      // El fold Left del historial no emite — conserva lo previo.
      expect(cubit.state.history, isEmpty);
    });

    test('las fixtures cubren los 5 carriles + los 3 serviceType — el '
        'entregado vive en active esperando el cierre', () async {
      final cubit = buildAdminQueueCubit();
      addTearDown(cubit.close);
      await cubit.load();

      final active = cubit.state.active;
      // Al menos un online con customerName y un presencial con mesa
      // (los dos extremos de la fila cliente de la card).
      expect(
        active.any(
          (o) =>
              o.channel == AdminOrderChannel.online && o.customerName != null,
        ),
        isTrue,
      );
      expect(
        active.any(
          (o) =>
              o.channel == AdminOrderChannel.presencial && o.tableLabel != null,
        ),
        isTrue,
      );
      // Los 5 carriles del kanban tienen pedido — incluido el done
      // sin cerrar que espera el cierre de caja (§036).
      for (final lane in AdminQueueState.laneStatuses) {
        expect(
          active.any((o) => o.status == lane),
          isTrue,
          reason: 'el carril $lane debe tener al menos un mock',
        );
      }
      expect(
        active.map((o) => o.serviceType).toSet(),
        containsAll([
          AdminServiceType.pickup,
          AdminServiceType.delivery,
          AdminServiceType.dineIn,
        ]),
      );
      expect(
        active.map((o) => o.paymentMethod).toSet(),
        containsAll([AdminPaymentMethod.cash, AdminPaymentMethod.transfer]),
      );
      expect(
        active.map((o) => o.paymentStatus).toSet(),
        containsAll([
          OrderPaymentStatus.pending,
          OrderPaymentStatus.paid,
          OrderPaymentStatus.failed,
        ]),
      );
      // Tres entregados en la cola viva + cancelados en el
      // historial (el done ya no cae a history de una — solo el
      // cancelled).
      expect(cubit.state.deliveredCount, 3);
      expect(cubit.state.history.every((o) => o.isTerminal), isTrue);
    });

    test('laneOrders: FIFO de cocina por carril (el que más espera '
        'va arriba) y deliveredCount cuenta los done del activo', () {
      final state = AdminQueueState(
        active: [
          _order('new', OrderStatus.confirmed, DateTime(2024, 1, 1, 12)),
          _order('old', OrderStatus.confirmed, DateTime(2024, 1, 1, 8)),
          _order('ready', OrderStatus.ready, DateTime(2024, 1, 1, 10)),
          _order('done', OrderStatus.done, DateTime(2024, 1, 1, 9)),
        ],
        dataLoading: false,
      );
      expect(
        state.laneOrders(OrderStatus.confirmed).map((o) => o.id),
        equals(['old', 'new']),
      );
      expect(state.laneOrders(OrderStatus.received), isEmpty);
      expect(state.deliveredCount, 1);
    });
  });

  group('AdminQueueCubit — refreshOrder §039 (GET /admin/orders/:id '
      'al abrir el detalle)', () {
    // El listado manda modifiers:[] a propósito — el :id trae la
    // comanda completa + el estado más fresco; refreshOrder la
    // inyecta en la bandeja donde vive la orden.
    AdminOrder snapshot(String id) =>
        _order(id, OrderStatus.received, DateTime(2024, 1, 1));

    test('reemplaza la orden en `active` — la comanda completa con '
        'modifiers + estado fresco sustituye el snapshot del listado',
        () async {
      final detail = FakeGetAdminOrderDetailUseCase();
      // Cambió a confirmed server-side y trae el "sin cebolla" que
      // el listado omite — ambas cosas llegan en el mismo GET.
      final full = AdminOrder(
        id: 'w1',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.delivery,
        status: OrderStatus.confirmed,
        items: const [
          OrderItem(
            productId: 'p-depredador',
            productSlug: 'depredador',
            name: 'El Depredador',
            quantity: 1,
            unitPrice: 25000,
            modifiers: [
              CartModifier(
                optionId: 'ing-cebolla',
                optionName: 'Cebolla',
                action: CartModifierAction.removed,
                priceDelta: 0,
              ),
            ],
          ),
        ],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 25000,
        deliveryFee: 0,
        placedAt: DateTime(2024, 1, 1),
      );
      when(() => detail.call('w1')).thenAnswer((_) async => Right(full));
      final cubit = buildAdminQueueCubit(
        active: [snapshot('w1')],
        history: const [],
        getOrderDetail: detail,
      );
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.refreshOrder('w1');

      // La orden viva es la del servidor — instancia completa.
      expect(cubit.state.orderById('w1'), same(full));
      // Refresh de fondo: sin spinner ni busy (no es mutación).
      expect(cubit.state.busyOrderIds, isEmpty);
    });

    test('reemplaza en `history` — el archivado también se refresca '
        'en su propia bandeja', () async {
      final detail = FakeGetAdminOrderDetailUseCase();
      final full = _order('h1', OrderStatus.cancelled, DateTime(2024, 1, 1));
      when(() => detail.call('h1')).thenAnswer((_) async => Right(full));
      final cubit = buildAdminQueueCubit(
        active: const [],
        history: [snapshot('h1')],
        getOrderDetail: detail,
      );
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.refreshOrder('h1');

      expect(cubit.state.orderById('h1'), same(full));
      // Refresh reemplaza en su bandeja — no migra a active.
      expect(cubit.state.active, isEmpty);
    });

    test('la orden NO está en ninguna bandeja → no-op (history solo '
        'carga página 1 — el detalle sigue con el snapshot del extra)',
        () async {
      final detail = FakeGetAdminOrderDetailUseCase();
      when(
        () => detail.call('ghost'),
      ).thenAnswer((_) async => Right(snapshot('ghost')));
      final cubit = buildAdminQueueCubit(
        active: [snapshot('w1')],
        history: const [],
        getOrderDetail: detail,
      );
      addTearDown(cubit.close);
      await cubit.load();
      final before = cubit.state;

      await cubit.refreshOrder('ghost');

      // Ni un emit — el state es literalmente el mismo.
      expect(cubit.state, same(before));
    });

    test('falla SILENCIOSA — el detalle ya renderiza el snapshot del '
        'extra: sin emit, sin toast, sin banner', () async {
      final detail = FakeGetAdminOrderDetailUseCase();
      when(
        () => detail.call('w1'),
      ).thenAnswer((_) async => const Left(AdminServerFailure('boom')));
      final cubit = buildAdminQueueCubit(
        active: [snapshot('w1')],
        history: const [],
        getOrderDetail: detail,
      );
      addTearDown(cubit.close);
      await cubit.load();
      final before = cubit.state;

      await cubit.refreshOrder('w1');

      expect(cubit.state, same(before));
      expect(cubit.state.failed, isFalse);
    });

    test('un load() posterior NO pisa la orden hidratada — los ítems '
        'con modifiers sobreviven al refresh de la cola (los ítems son '
        'inmutables: el listado los manda vacíos, el detalle los trajo)',
        () async {
      final detail = FakeGetAdminOrderDetailUseCase();
      final full = _order(
        'w1',
        OrderStatus.received,
        DateTime(2024, 1, 1),
      ).copyWith(
        items: const [
          OrderItem(
            productId: 'p-depredador',
            productSlug: 'depredador',
            name: 'El Depredador',
            quantity: 1,
            unitPrice: 25000,
            modifiers: [
              CartModifier(
                optionId: 'ing-cebolla',
                optionName: 'Cebolla',
                action: CartModifierAction.removed,
                priceDelta: 0,
              ),
            ],
          ),
        ],
      );
      when(() => detail.call('w1')).thenAnswer((_) async => Right(full));
      final cubit = buildAdminQueueCubit(
        active: [snapshot('w1')],
        history: const [],
        getOrderDetail: detail,
      );
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.refreshOrder('w1');

      // Carrera real §039: la cola se re-carga (pull del dueño, re-entry
      // del tab) DESPUÉS de que el detalle hidrató la orden — el
      // snapshot del listado no debe borrar los modifiers.
      await cubit.load();

      final order = cubit.state.orderById('w1')!;
      expect(order.items.single.modifiers, hasLength(1));
      expect(order.items.single.modifiers.single.optionName, 'Cebolla');
    });
  });

  group('AdminQueueCubit — operaciones §040 (PATCH real — el echo '
      'del fixture simula el servidor que aplica el `to` pedido)', () {
    // advance/cancel ya pegan a UpdateAdminOrderStatusUseCase — el
    // stub echo de buildAdminQueueCubit juega de backend (aplica `to`
    // y re-sella statusChangedAt). markPaid sigue local hasta §041.
    Future<AdminQueueCubit> loaded() async {
      final cubit = buildAdminQueueCubit();
      addTearDown(cubit.close);
      await cubit.load();
      return cubit;
    }

    test('advanceOrder: la matriz de 5 pasos received→confirmed→'
        'preparing→ready→done, cada paso un toque', () async {
      final order = _order('w1', OrderStatus.received, DateTime(2024, 1, 1));
      final cubit = buildAdminQueueCubit(active: [order], history: const []);
      addTearDown(cubit.close);
      await cubit.load();

      for (final next in [
        OrderStatus.confirmed,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.done,
      ]) {
        await cubit.advanceOrder('w1');
        expect(cubit.state.orderById('w1')!.status, next);
      }
      // El done NO cruza a history — vive en el carril Entregado
      // hasta el cierre de caja (decisión §022).
      expect(cubit.state.active.any((o) => o.id == 'w1'), isTrue);
      expect(cubit.state.history, isEmpty);
    });

    test('advanceOrder: done queda en Activos (carril Entregado) — '
        'no se archiva hasta el cierre', () async {
      final cubit = await loaded();

      // adm-3 = Beto Dos (ready, pickup, transferencia pagada).
      await cubit.advanceOrder('adm-3');

      final moved = cubit.state.orderById('adm-3')!;
      expect(moved.status, OrderStatus.done);
      expect(cubit.state.active.any((o) => o.id == 'adm-3'), isTrue);
      expect(cubit.state.history.any((o) => o.id == 'adm-3'), isFalse);
      // Ya son 4 entregados esperando cierre.
      expect(cubit.state.deliveredCount, 4);
    });

    test('markPaid: ready + pago pendiente → paga Y CIERRA de una '
        '— cobrar era el único bloqueo (§036)', () async {
      final cubit = await loaded();

      // adm-8 = Mesa 7 (ready, dine_in, efectivo pendiente): la
      // mesa pidió la cuenta — Registrar pago cobra y cierra en
      // el mismo toque (§036, decisión del dueño).
      await cubit.markPaid('adm-8');

      final order = cubit.state.orderById('adm-8')!;
      expect(order.paymentStatus, OrderPaymentStatus.paid);
      expect(order.status, OrderStatus.done);
      // Sigue en active — el carril Entregado espera el cierre.
      expect(cubit.state.active.any((o) => o.id == 'adm-8'), isTrue);
      expect(cubit.state.busyOrderIds, isEmpty);
    });

    test('cancelOrder: → cancelled al Historial con el motivo '
        'guardado — el único que cruza de una', () async {
      final cubit = await loaded();

      await cubit.cancelOrder('adm-1', reason: '  se acabó el pan  ');

      final order = cubit.state.orderById('adm-1')!;
      expect(order.status, OrderStatus.cancelled);
      expect(order.cancelReason, 'se acabó el pan');
      expect(cubit.state.active.any((o) => o.id == 'adm-1'), isFalse);
      expect(cubit.state.history.first.id, 'adm-1');
    });

    test('cancelOrder sin motivo: acepta vacío → cancelReason null', () async {
      final cubit = await loaded();

      await cubit.cancelOrder('adm-4');

      final order = cubit.state.orderById('adm-4')!;
      expect(order.status, OrderStatus.cancelled);
      expect(order.cancelReason, isNull);
    });

    test('markPaid: pago failed → pagado — un cobro rechazado '
        'sigue debiendo (contrato §035)', () async {
      final failed = _order(
        'f1',
        OrderStatus.confirmed,
        DateTime(2024, 1, 1),
      ).copyWith(paymentStatus: OrderPaymentStatus.failed);
      final cubit = buildAdminQueueCubit(active: [failed], history: const []);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.markPaid('f1');

      expect(
        cubit.state.orderById('f1')!.paymentStatus,
        OrderPaymentStatus.paid,
      );
      expect(cubit.state.orderById('f1')!.status, OrderStatus.confirmed);
    });

    test('advanceOrder: la recogida PRESENCIAL sin cobrar NO confirma '
        '— la puerta de pago del §036 (local = no-op, prod = 409)', () async {
      final cubit = await loaded();

      // adm-33 = pickup presencial por teléfono, transfer pendiente:
      // el dueño certifica la plata a mano — sin ella no entra a
      // cocina. adm-25 = mostrador cash pendiente: mismo bloqueo.
      await cubit.advanceOrder('adm-33');
      expect(cubit.state.orderById('adm-33')!.status, OrderStatus.received);
      await cubit.advanceOrder('adm-25');
      expect(cubit.state.orderById('adm-25')!.status, OrderStatus.received);

      // Cobrada sí: "Registrar pago" cobra Y confirma en el mismo
      // toque — el pago era el único bloqueo (§036, decisión del
      // dueño); la card pasa directo al carril Confirmado.
      await cubit.markPaid('adm-33');
      expect(cubit.state.orderById('adm-33')!.status, OrderStatus.confirmed);
      // La recogida ONLINE no pasa por aquí — solo acepta Nequi:
      // congelada hasta el webhook (test de abajo).
      // Y el delivery sin cobrar de al lado sí confirmaba libre —
      // la puerta solo es de la recogida.
      await cubit.advanceOrder('adm-1');
      expect(cubit.state.orderById('adm-1')!.status, OrderStatus.confirmed);
    });

    test('advanceOrder: el cobro Nequi NO se adelanta — congelado '
        'hasta el webhook (§036)', () async {
      final cubit = await loaded();

      // adm-29/30 = Nequi pending — ni pickup ni delivery avanzan:
      // la regla congela TODO el Nequi sin confirmar, no solo la
      // recogida.
      await cubit.advanceOrder('adm-29');
      await cubit.advanceOrder('adm-30');
      expect(cubit.state.orderById('adm-29')!.status, OrderStatus.received);
      expect(cubit.state.orderById('adm-30')!.status, OrderStatus.received);

      // adm-31 = Nequi FALLIDO — el webhook ya dijo que no: tampoco
      // avanza (solo queda cancelar).
      await cubit.advanceOrder('adm-31');
      expect(cubit.state.orderById('adm-31')!.status, OrderStatus.received);

      // El pedido cancelable sí sale — failed no es terminal de
      // pedido, solo de pago. (orderById busca en ambos buckets:
      // en activo ya no está, en historial quedó cancelado).
      await cubit.cancelOrder('adm-31');
      expect(cubit.state.active.any((o) => o.id == 'adm-31'), isFalse);
      expect(
        cubit.state.orderById('adm-31')!.status,
        OrderStatus.cancelled,
        reason: 'adm-31 cruzó al historial',
      );
    });

    test('markPaid: Nequi NUNCA se cobra a mano — ni pending ni '
        'failed lo registra el dueño (§036)', () async {
      final cubit = await loaded();

      await cubit.markPaid('adm-29');
      expect(
        cubit.state.orderById('adm-29')!.paymentStatus,
        OrderPaymentStatus.pending,
      );
      await cubit.markPaid('adm-31');
      expect(
        cubit.state.orderById('adm-31')!.paymentStatus,
        OrderPaymentStatus.failed,
      );
      // La única salida del pending sería el webhook (paid de
      // fuera) — el mock no lo simula porque no hay endpoint aún.
    });

    test('no-ops: advance sobre terminal y markPaid sobre ya pagado '
        'no mutan nada', () async {
      final cubit = await loaded();

      // adm-5 ya está done (en el carril Entregado del activo).
      await cubit.advanceOrder('adm-5');
      expect(cubit.state.orderById('adm-5')!.status, OrderStatus.done);
      expect(cubit.state.active.any((o) => o.id == 'adm-5'), isTrue);

      // adm-6 cancelado en el historial — terminal sin acción.
      await cubit.advanceOrder('adm-6');
      expect(cubit.state.orderById('adm-6')!.status, OrderStatus.cancelled);

      // adm-3 ya está pagado — no cambia de método ni de bucket.
      final before = cubit.state.orderById('adm-3');
      await cubit.markPaid('adm-3');
      expect(cubit.state.orderById('adm-3'), before);
      expect(cubit.state.busyOrderIds, isEmpty);
    });

    test('un load() posterior RESINCRONIZA la cola — lo que el '
        'servidor reporta manda sobre el estado local (§040)', () async {
      final cubit = await loaded();

      await cubit.advanceOrder('adm-3'); // Beto → done (PATCH echo).
      await cubit.load();

      // El resync devuelve la fixture del "servidor" (ready otra vez)
      // — en producción el PATCH persiste y el load traería done.
      expect(cubit.state.orderById('adm-3')!.status, OrderStatus.ready);
      expect(cubit.state.deliveredCount, 3);
    });
  });

  group('AdminQueueCubit — mutaciones remotas §040 (PATCH '
      '/admin/orders/:id/status)', () {
    // Cubit armado a mano: los 3 fakes nombrados para stub-lear y
    // verificar el PATCH directo (buildAdminQueueCubit esconde el
    // update echo detrás de su firma).
    FakeLoadAdminQueueUseCase loadUseCase(
      List<AdminOrder> active, [
      List<AdminOrder> history = const [],
    ]) {
      final uc = FakeLoadAdminQueueUseCase();
      when(uc.call).thenAnswer(
        (_) async => AdminQueueData(
          active: Right(active),
          history: Right(
            AdminHistoryPage(items: history, total: history.length),
          ),
        ),
      );
      return uc;
    }

    FakeGetAdminOrderDetailUseCase silentDetail() {
      final d = FakeGetAdminOrderDetailUseCase();
      when(
        () => d.call(any()),
      ).thenAnswer((_) async => const Left(AdminServerFailure('stub')));
      return d;
    }

    AdminQueueCubit cubit({
      required FakeLoadAdminQueueUseCase loadQueue,
      required FakeUpdateAdminOrderStatusUseCase update,
      FakeGetAdminOrderDetailUseCase? detail,
    }) => AdminQueueCubit(
      loadQueue: loadQueue,
      getOrderDetail: detail ?? silentDetail(),
      updateOrderStatus: update,
    );

    test('advanceOrder: la entidad devuelta por el PATCH REEMPLAZA al '
        'snapshot — statusChangedAt lo sella el servidor (el reloj de '
        'la cola no es el del teléfono)', () async {
      final local = _order('w1', OrderStatus.received, DateTime(2024, 1, 1));
      final serverClock = DateTime(2026, 11, 8, 18);
      final moved = AdminOrder(
        id: 'w1',
        channel: AdminOrderChannel.online,
        serviceType: AdminServiceType.delivery,
        status: OrderStatus.confirmed,
        statusChangedAt: serverClock,
        items: const [],
        paymentMethod: AdminPaymentMethod.cash,
        paymentStatus: OrderPaymentStatus.paid,
        subtotal: 10000,
        deliveryFee: 0,
        placedAt: DateTime(2024, 1, 1),
      );
      final update = FakeUpdateAdminOrderStatusUseCase();
      when(
        () => update.call(
          'w1',
          to: 'confirmed',
          cancelReason: any(named: 'cancelReason'),
        ),
      ).thenAnswer((_) async => Right(moved));
      final c = cubit(loadQueue: loadUseCase([local]), update: update);
      addTearDown(c.close);
      await c.load();

      final failure = await c.advanceOrder('w1');

      expect(failure, isNull);
      // La MISMA instancia del servidor — no un copyWith local.
      expect(c.state.orderById('w1'), same(moved));
      expect(c.state.orderById('w1')!.statusChangedAt, serverClock);
      expect(c.state.busyOrderIds, isEmpty);
    });

    test('cancelOrder: el PATCH cancelled migra la orden al FRENTE '
        'del historial y el motivo viaja al body (§040)', () async {
      final order = _order('w1', OrderStatus.confirmed, DateTime(2024, 1, 1));
      final old = _order('h9', OrderStatus.cancelled, DateTime(2024, 1, 2));
      final update = FakeUpdateAdminOrderStatusUseCase();
      stubUpdateEcho(update, [order, old]);
      final c = cubit(
        loadQueue: loadUseCase([order], [old]),
        update: update,
      );
      addTearDown(c.close);
      await c.load();

      final failure = await c.cancelOrder('w1', reason: '  se acabó el pan  ');

      expect(failure, isNull);
      verify(
        () => update.call(
          'w1',
          to: 'cancelled',
          cancelReason: 'se acabó el pan',
        ),
      ).called(1);
      expect(c.state.active.any((o) => o.id == 'w1'), isFalse);
      final cancelled = c.state.history.first;
      expect(cancelled.id, 'w1');
      expect(cancelled.status, OrderStatus.cancelled);
      expect(cancelled.cancelReason, 'se acabó el pan');
      // El done NO migra — solo cancelled cruza de una (§022).
      expect(c.state.history, hasLength(2));
    });

    test('respuesta PATCH con modifiers vacíos NO pisa los ítems '
        'hidratados por el detalle — la vista de listado los omite '
        '(§040 reusa _preserveHydrated del §039)', () async {
      final local = _order('w1', OrderStatus.received, DateTime(2024, 1, 1));
      const hydratedItem = OrderItem(
        productId: 'p-depredador',
        productSlug: 'depredador',
        name: 'El Depredador',
        quantity: 1,
        unitPrice: 25000,
        modifiers: [
          CartModifier(
            optionId: 'ing-cebolla',
            optionName: 'Cebolla',
            action: CartModifierAction.removed,
            priceDelta: 0,
          ),
        ],
      );
      final detail = FakeGetAdminOrderDetailUseCase();
      when(() => detail.call('w1')).thenAnswer(
        (_) async => Right(local.copyWith(items: const [hydratedItem])),
      );
      // El PATCH responde la vista de listado — mismo ítem SIN modifiers.
      final update = FakeUpdateAdminOrderStatusUseCase();
      when(
        () => update.call(
          'w1',
          to: 'confirmed',
          cancelReason: any(named: 'cancelReason'),
        ),
      ).thenAnswer(
        (_) async => Right(
          AdminOrder(
            id: 'w1',
            channel: AdminOrderChannel.online,
            serviceType: AdminServiceType.delivery,
            status: OrderStatus.confirmed,
            items: const [
              OrderItem(
                productId: 'p-depredador',
                productSlug: 'depredador',
                name: 'El Depredador',
                quantity: 1,
                unitPrice: 25000,
              ),
            ],
            paymentMethod: AdminPaymentMethod.cash,
            paymentStatus: OrderPaymentStatus.paid,
            subtotal: 10000,
            deliveryFee: 0,
            placedAt: DateTime(2024, 1, 1),
          ),
        ),
      );
      final c = cubit(
        loadQueue: loadUseCase([local]),
        update: update,
        detail: detail,
      );
      addTearDown(c.close);
      await c.load();
      await c.refreshOrder('w1'); // hidrata los modifiers del :id

      await c.advanceOrder('w1');

      final w1 = c.state.orderById('w1')!;
      expect(w1.status, OrderStatus.confirmed);
      expect(w1.items.single.modifiers, hasLength(1));
      expect(w1.items.single.modifiers.single.optionName, 'Cebolla');
    });

    test('409 → devuelve AdminConflictFailure y dispara el resync '
        'silencioso de la cola (el pedido ya cambió server-side — '
        'convención OrdersCubit §027)', () async {
      final local = _order('w1', OrderStatus.received, DateTime(2024, 1, 1));
      final load = loadUseCase([local]);
      final update = FakeUpdateAdminOrderStatusUseCase();
      when(
        () => update.call(
          'w1',
          to: 'confirmed',
          cancelReason: any(named: 'cancelReason'),
        ),
      ).thenAnswer(
        (_) async =>
            const Left(AdminConflictFailure('INVALID_STATUS_TRANSITION')),
      );
      final c = cubit(loadQueue: load, update: update);
      addTearDown(c.close);
      await c.load();

      final failure = await c.advanceOrder('w1');

      expect(
        failure,
        const AdminConflictFailure('INVALID_STATUS_TRANSITION'),
      );
      // El resync corrió en segundo plano — segundo llamado al load.
      verify(() => load.call()).called(2);
      // Sin mutación optimista: la orden sigue como el servidor la
      // reportó (recibida, en el fixture).
      expect(c.state.orderById('w1')!.status, OrderStatus.received);
      expect(c.state.busyOrderIds, isEmpty);
    });

    test('busy anti-reentry: el segundo advance sobre el mismo pedido '
        'es no-op mientras el PATCH sigue en vuelo (doble-tap §035)',
        () async {
      final local = _order('w1', OrderStatus.received, DateTime(2024, 1, 1));
      final update = FakeUpdateAdminOrderStatusUseCase();
      final completer = Completer<Either<AdminFailure, AdminOrder>>();
      when(
        () => update.call(
          'w1',
          to: 'confirmed',
          cancelReason: any(named: 'cancelReason'),
        ),
      ).thenAnswer((_) => completer.future);
      final c = cubit(loadQueue: loadUseCase([local]), update: update);
      addTearDown(c.close);
      await c.load();

      final first = c.advanceOrder('w1'); // entra: emite busy + PATCH
      expect(c.state.busyOrderIds, contains('w1'));

      final second = await c.advanceOrder('w1'); // busy → no-op
      expect(second, isNull);
      verify(
        () => update.call(
          'w1',
          to: 'confirmed',
          cancelReason: any(named: 'cancelReason'),
        ),
      ).called(1);

      completer.complete(
        Right(local.copyWith(status: OrderStatus.confirmed)),
      );
      expect(await first, isNull);
      expect(c.state.orderById('w1')!.status, OrderStatus.confirmed);
      expect(c.state.busyOrderIds, isEmpty);
    });

    test('puertas locales = no-op SIN pegar al PATCH: terminal, Nequi '
        'en espera del webhook, pickup sin cobrar e id desconocido '
        '(el 409 del backend queda para estado viejo)', () async {
      final orders = [
        _order('done', OrderStatus.done, DateTime(2024, 1, 1)),
        _order(
          'nequi',
          OrderStatus.received,
          DateTime(2024, 1, 1),
          method: AdminPaymentMethod.nequi,
          payment: OrderPaymentStatus.pending,
        ),
        _order(
          'pickup',
          OrderStatus.received,
          DateTime(2024, 1, 1),
          serviceType: AdminServiceType.pickup,
          payment: OrderPaymentStatus.pending,
        ),
      ];
      final update = FakeUpdateAdminOrderStatusUseCase();
      final c = cubit(loadQueue: loadUseCase(orders), update: update);
      addTearDown(c.close);
      await c.load();

      expect(await c.advanceOrder('done'), isNull); // terminal
      expect(await c.advanceOrder('nequi'), isNull); // awaitsWebhook
      expect(await c.advanceOrder('pickup'), isNull); // puerta de pago
      expect(await c.advanceOrder('ghost'), isNull); // fuera del state
      // Cancel sobre terminal tampoco pega.
      expect(await c.cancelOrder('done'), isNull);

      verifyNever(
        () => update.call(
          any(),
          to: any(named: 'to'),
          cancelReason: any(named: 'cancelReason'),
        ),
      );
      // Sin toques al servidor → sin busy prendido.
      expect(c.state.busyOrderIds, isEmpty);
      expect(c.state.orderById('done')!.status, OrderStatus.done);
    });

    test('markPaid sigue LOCAL — no pega al PATCH de status (su '
        'endpoint es confirm-payment, ciclo §041)', () async {
      final order = _order(
        'w1',
        OrderStatus.ready,
        DateTime(2024, 1, 1),
        payment: OrderPaymentStatus.pending,
      );
      final update = FakeUpdateAdminOrderStatusUseCase();
      final c = cubit(loadQueue: loadUseCase([order]), update: update);
      addTearDown(c.close);
      await c.load();

      await c.markPaid('w1');

      verifyNever(
        () => update.call(
          any(),
          to: any(named: 'to'),
          cancelReason: any(named: 'cancelReason'),
        ),
      );
      final w1 = c.state.orderById('w1')!;
      expect(w1.paymentStatus, OrderPaymentStatus.paid);
      // Cobrar era el único bloqueo — cierra de una (§036).
      expect(w1.status, OrderStatus.done);
      expect(c.state.busyOrderIds, isEmpty);
    });
  });

  group('AdminQueueCubit — cierre de caja §036', () {
    test('loadDayClosePreview: resumen del día — entregados, total, '
        'por método y cancelados como contexto', () async {
      final cubit = buildAdminQueueCubit();
      addTearDown(cubit.close);
      await cubit.load();

      cubit.loadDayClosePreview();

      final preview = cubit.state.dayClose!;
      // Tres done-sin-cerrar: adm-16 ($26.000 cash), adm-17
      // ($14.000 transfer) y adm-5 ($25.000 transfer) — el desglose
      // itera el orden del activo: cash primero.
      expect(preview.orderCount, 3);
      expect(preview.totalAmount, 65000);
      expect(
        preview.byMethod,
        equals([
          const AdminDayCloseMethod(method: 'cash', count: 1, amount: 26000),
          const AdminDayCloseMethod(
            method: 'transfer',
            count: 2,
            amount: 39000,
          ),
        ]),
      );
      // Tres cancelados $85.000 — contexto, no suman al total.
      expect(preview.cancelledCount, 3);
      expect(preview.cancelledAmount, 85000);
      // El preview NO muta la cola.
      expect(cubit.state.active, hasLength(30));
      expect(cubit.state.history, hasLength(3));
    });

    test('closeDay: archiva los done al history, devuelve el resumen '
        'y el carril Entregado queda vacío de verdad', () async {
      final cubit = buildAdminQueueCubit();
      addTearDown(cubit.close);
      await cubit.load();

      final summary = await cubit.closeDay();

      expect(summary!.orderCount, 3);
      expect(summary.totalAmount, 65000);
      expect(cubit.state.dayCloseBusy, isFalse);
      // Los 3 done se archivaron al frente del historial (en orden
      // del activo: adm-16 primero); el carril Entregado quedó
      // vacío.
      expect(cubit.state.deliveredCount, 0);
      expect(cubit.state.active.any((o) => o.id == 'adm-5'), isFalse);
      expect(cubit.state.active.any((o) => o.id == 'adm-16'), isFalse);
      expect(cubit.state.active.any((o) => o.id == 'adm-17'), isFalse);
      expect(cubit.state.history.first.id, 'adm-16');
      // PROVISIONAL (§038): un load posterior vuelve a traer los
      // done del "servidor" (fixture) — el archivo local del cierre
      // no persiste hasta el ciclo de integración del day-close.
      await cubit.load();
      expect(cubit.state.deliveredCount, 3);
    });

    test('closeDay: cierre vacío permitido — resumen en ceros con '
        'los cancelados como contexto', () async {
      final cubit = buildAdminQueueCubit(
        active: [_order('a1', OrderStatus.preparing, DateTime(2024, 1, 1))],
        history: const [],
      );
      addTearDown(cubit.close);
      await cubit.load();

      final summary = await cubit.closeDay();

      expect(summary!.orderCount, 0);
      expect(summary.totalAmount, 0);
      expect(summary.byMethod, isEmpty);
      expect(summary.isEmpty, isTrue);
      // El pedido en curso sigue en la cola — el cierre solo
      // archiva entregados.
      expect(cubit.state.active.any((o) => o.id == 'a1'), isTrue);
    });
  });
}
