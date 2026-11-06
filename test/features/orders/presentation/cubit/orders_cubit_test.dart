import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';
import 'package:depredadog_app/features/orders/presentation/cubit/orders_cubit.dart';
import 'package:depredadog_app/features/orders/presentation/cubit/orders_state.dart';

void main() {
  group('estado inicial (§023 — mocks de presentación)', () {
    test('3 activos (delivery "En la plancha" Nequi + pickup "Recibido" '
        '+ delivery "Confirmado" en efectivo) y 3 en el historial', () {
      final cubit = OrdersCubit();
      addTearDown(cubit.close);

      expect(cubit.state.active, hasLength(3));
      expect(cubit.state.active.first.id, 'ord-1');
      expect(cubit.state.active.first.status, OrderStatus.preparing);
      expect(cubit.state.active.last.id, 'ord-6');
      // Solo el "Recibido" (ord-2) es cancelable (regla backend 015).
      expect(
        cubit.state.active.where((o) => o.isCancellable).single.id,
        'ord-2',
      );
      // El nuevo caso: domicilio pagando en efectivo contra entrega.
      expect(
        cubit.state.active.last.paymentMethod,
        OrderPaymentMethod.onDelivery,
      );
      expect(cubit.state.history, hasLength(3));
      expect(cubit.state.isEmpty, isFalse);
    });

    test('semillas vacías → isEmpty (vista vacía del tab)', () {
      final cubit = OrdersCubit(seedActive: const [], seedHistory: const []);
      addTearDown(cubit.close);

      expect(cubit.state.active, isEmpty);
      expect(cubit.state.history, isEmpty);
      expect(cubit.state.isEmpty, isTrue);
    });
  });

  group('cancelOrder (§023 mock — solo pending)', () {
    blocTest<OrdersCubit, OrdersState>(
      '"Recibido" → sale de En curso y encabeza el historial cancelled',
      build: OrdersCubit.new,
      act: (cubit) => cubit.cancelOrder('ord-2'),
      verify: (cubit) {
        expect(cubit.state.active, hasLength(2));
        expect(
          cubit.state.active.map((o) => o.id),
          containsAll(<String>['ord-1', 'ord-6']),
        );
        expect(cubit.state.history, hasLength(4));
        final cancelled = cubit.state.history.first;
        expect(cancelled.id, 'ord-2');
        expect(cancelled.status, OrderStatus.cancelled);
        expect(cancelled.cancelReason, 'Cancelado por el cliente');
        expect(cancelled.statusChangedAt, isNotNull);
      },
    );

    blocTest<OrdersCubit, OrdersState>(
      '"En la plancha" NO se cancela — sin emisión (regla pending)',
      build: OrdersCubit.new,
      act: (cubit) => cubit.cancelOrder('ord-1'),
      expect: () => <OrdersState>[],
      verify: (cubit) {
        expect(cubit.state.active, hasLength(3));
        expect(cubit.state.history, hasLength(3));
      },
    );

    blocTest<OrdersCubit, OrdersState>(
      'id inexistente → sin emisión',
      build: OrdersCubit.new,
      act: (cubit) => cubit.cancelOrder('ord-999'),
      expect: () => <OrdersState>[],
    );
  });
}
