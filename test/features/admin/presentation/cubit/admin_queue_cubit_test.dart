import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_day_close.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_queue_cubit.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_queue_state.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';

AdminOrder _order(String id, OrderStatus status, DateTime placedAt) =>
    AdminOrder(
      id: id,
      channel: AdminOrderChannel.online,
      serviceType: AdminServiceType.delivery,
      status: status,
      items: const [],
      paymentMethod: AdminPaymentMethod.cash,
      paymentStatus: OrderPaymentStatus.paid,
      total: 10000,
      placedAt: placedAt,
    );

void main() {
  group('AdminQueueCubit (§036 — mocks de fase 1, kanban)', () {
    test('estado inicial: cargando, bandejas vacías, sin preview de '
        'cierre ni busy', () {
      final cubit = AdminQueueCubit();
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
      'load(): emite cargando → cola mock completa (30 activos + 3 '
      'historial — todas las variantes de la puerta de pago)',
      build: AdminQueueCubit.new,
      act: (cubit) => cubit.load(),
      // El mock simula 400ms de latencia (convención §023).
      wait: const Duration(milliseconds: 500),
      expect: () => [
        isA<AdminQueueState>()
            .having((s) => s.dataLoading, 'dataLoading', isTrue)
            .having((s) => s.failed, 'failed', isFalse),
        isA<AdminQueueState>()
            .having((s) => s.active.length, 'active', 30)
            .having((s) => s.history.length, 'history', 3)
            .having((s) => s.dataLoading, 'dataLoading', isFalse),
      ],
    );

    test('los mocks cubren los 5 carriles + los 3 serviceType — el '
        'entregado vive en active esperando el cierre', () async {
      final cubit = AdminQueueCubit();
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

  group('AdminQueueCubit — operaciones §036 (mocks con latencia)', () {
    // Cada operación lleva ~400ms de latencia simulada como load() —
    // los awaits corren en tiempo real (convención del archivo).
    Future<AdminQueueCubit> loaded() async {
      final cubit = AdminQueueCubit();
      addTearDown(cubit.close);
      await cubit.load();
      return cubit;
    }

    test('advanceOrder: la matriz de 5 pasos received→confirmed→'
        'preparing→ready→done, cada paso un toque', () async {
      final order = _order('w1', OrderStatus.received, DateTime(2024, 1, 1));
      final cubit = AdminQueueCubit(mockActive: [order], mockHistory: const []);
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
      final cubit = AdminQueueCubit(
        mockActive: [failed],
        mockHistory: const [],
      );
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
        '— la puerta de pago del §036 (mock = no-op, prod = 409)', () async {
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

    test('la mutación persiste en los mocks: un load() posterior no '
        'resucita el pedido ya operado', () async {
      final cubit = await loaded();

      await cubit.advanceOrder('adm-3'); // Beto → done.
      await cubit.load();

      // Los mocks son el "servidor" — el pull re-lee lo operado.
      expect(cubit.state.orderById('adm-3')!.status, OrderStatus.done);
      expect(cubit.state.deliveredCount, 4);
    });
  });

  group('AdminQueueCubit — cierre de caja §036', () {
    test('loadDayClosePreview: resumen del día — entregados, total, '
        'por método y cancelados como contexto', () async {
      final cubit = AdminQueueCubit();
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
      final cubit = AdminQueueCubit();
      addTearDown(cubit.close);
      await cubit.load();

      final closing = cubit.closeDay();
      expect(cubit.state.dayCloseBusy, isTrue);
      final summary = await closing;

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
      // Un load posterior no resucita el entregado archivado.
      await cubit.load();
      expect(cubit.state.deliveredCount, 0);
    });

    test('closeDay: cierre vacío permitido — resumen en ceros con '
        'los cancelados como contexto', () async {
      final cubit = AdminQueueCubit(
        mockActive: [_order('a1', OrderStatus.preparing, DateTime(2024, 1, 1))],
        mockHistory: const [],
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
