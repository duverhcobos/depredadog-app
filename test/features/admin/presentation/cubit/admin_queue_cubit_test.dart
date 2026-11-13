import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_queue_cubit.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_queue_state.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';

AdminOrder _order(String id, OrderStatus status, DateTime placedAt) =>
    AdminOrder(
      id: id,
      channel: AdminOrderChannel.online,
      status: status,
      items: const [],
      paymentMethod: AdminPaymentMethod.cash,
      paymentStatus: OrderPaymentStatus.paid,
      total: 10000,
      placedAt: placedAt,
    );

void main() {
  group('AdminQueueCubit (§034 — mocks de fase 1)', () {
    test('estado inicial: cargando, filtro Activos, bandejas vacías', () {
      final cubit = AdminQueueCubit();
      addTearDown(cubit.close);

      expect(cubit.state.dataLoading, isTrue);
      expect(cubit.state.failed, isFalse);
      expect(cubit.state.filter, AdminQueueFilter.active);
      expect(cubit.state.active, isEmpty);
      expect(cubit.state.history, isEmpty);
      expect(cubit.state.visible, isEmpty);
    });

    blocTest<AdminQueueCubit, AdminQueueState>(
      'load(): emite cargando → cola mock completa (5 activos + 2 historial)',
      build: AdminQueueCubit.new,
      act: (cubit) => cubit.load(),
      // El mock simula 400ms de latencia (convención §023).
      wait: const Duration(milliseconds: 500),
      expect: () => [
        isA<AdminQueueState>()
            .having((s) => s.dataLoading, 'dataLoading', isTrue)
            .having((s) => s.failed, 'failed', isFalse),
        isA<AdminQueueState>()
            .having((s) => s.active.length, 'active', 5)
            .having((s) => s.history.length, 'history', 2)
            .having((s) => s.dataLoading, 'dataLoading', isFalse),
      ],
    );

    test('los mocks cubren la matriz de la card: canales, estados, '
        'pagos, mesa y nombre de cliente', () async {
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
      // Estados vivos y métodos/estados de pago variados.
      expect(
        active.map((o) => o.status).toSet(),
        containsAll([
          OrderStatus.received,
          OrderStatus.confirmed,
          OrderStatus.preparing,
        ]),
      );
      expect(
        active.map((o) => o.paymentMethod).toSet(),
        containsAll([AdminPaymentMethod.cash, AdminPaymentMethod.transfer]),
      );
      expect(
        active.map((o) => o.paymentStatus).toSet(),
        containsAll([OrderPaymentStatus.pending, OrderPaymentStatus.paid]),
      );
      // Ningún activo es terminal; el historial lo es TODO.
      expect(active.every((o) => !o.isTerminal), isTrue);
      expect(cubit.state.history.every((o) => o.isTerminal), isTrue);
    });

    blocTest<AdminQueueCubit, AdminQueueState>(
      'setFilter(): marca el segmento y visible swappea de bandeja',
      build: AdminQueueCubit.new,
      seed: () => AdminQueueState(
        active: [_order('a1', OrderStatus.received, DateTime(2024, 1, 2))],
        history: [
          _order('h1', OrderStatus.done, DateTime(2024, 1, 1, 10)),
          _order('h2', OrderStatus.cancelled, DateTime(2024, 1, 1, 12)),
        ],
        dataLoading: false,
      ),
      act: (cubit) => cubit.setFilter(AdminQueueFilter.history),
      expect: () => [
        isA<AdminQueueState>().having(
          (s) => s.filter,
          'filter',
          AdminQueueFilter.history,
        ),
      ],
      // `visible` devuelve una copia ordenada (más reciente primero),
      // no la misma lista — la aserción es de contenido, no identidad.
      verify: (cubit) =>
          expect(cubit.state.visible.map((o) => o.id), equals(['h2', 'h1'])),
    );

    test('visible (Activos): por-confirmar primero (FIFO), luego el '
        'resto en FIFO de cocina — contrato de escaneo §034', () {
      final state = AdminQueueState(
        active: [
          _order('preparing', OrderStatus.preparing, DateTime(2024, 1, 1, 10)),
          _order(
            'received-new',
            OrderStatus.received,
            DateTime(2024, 1, 1, 12),
          ),
          _order('confirmed', OrderStatus.confirmed, DateTime(2024, 1, 1, 9)),
          _order('received-old', OrderStatus.received, DateTime(2024, 1, 1, 8)),
        ],
        dataLoading: false,
      );
      expect(
        state.visible.map((o) => o.id),
        equals(['received-old', 'received-new', 'confirmed', 'preparing']),
      );
    });

    test('visible (Historial): más reciente primero — log de salida', () {
      final state = AdminQueueState(
        history: [
          _order('old', OrderStatus.done, DateTime(2024, 1, 1, 10)),
          _order('new', OrderStatus.cancelled, DateTime(2024, 1, 1, 12)),
        ],
        filter: AdminQueueFilter.history,
        dataLoading: false,
      );
      expect(state.visible.map((o) => o.id), equals(['new', 'old']));
    });
  });
}
