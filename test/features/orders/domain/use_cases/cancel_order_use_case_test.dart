import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';
import 'package:depredadog_app/features/orders/domain/failures/orders_failure.dart';
import 'package:depredadog_app/features/orders/domain/repositories/i_orders_repository.dart';
import 'package:depredadog_app/features/orders/domain/use_cases/cancel_order_use_case.dart';

class MockOrdersRepository extends Mock implements IOrdersRepository {}

void main() {
  late MockOrdersRepository repo;
  late CancelOrderUseCase useCase;

  final cancelled = CustomerOrder(
    id: 'ord-1',
    serviceType: OrderServiceType.pickup,
    status: OrderStatus.cancelled,
    items: const [],
    paymentMethod: OrderPaymentMethod.nequi,
    paymentStatus: OrderPaymentStatus.failed,
    subtotal: 14000,
    deliveryFee: 0,
    placedAt: DateTime(2026, 11, 8, 12, 40),
    cancelReason: 'Cancelado por el cliente',
  );

  setUp(() {
    repo = MockOrdersRepository();
    useCase = CancelOrderUseCase(repo);
  });

  test('delegación: id + reason al repo y devuelve su Either', () async {
    when(() => repo.cancelOrder('ord-1', 'Cancelado por el cliente'))
        .thenAnswer((_) async => Right(cancelled));

    final result = await useCase('ord-1', 'Cancelado por el cliente');

    expect(result, Right<OrdersFailure, CustomerOrder>(cancelled));
    verify(() => repo.cancelOrder('ord-1', 'Cancelado por el cliente'))
        .called(1);
  });

  test('el Left del repo viaja sin tocar (409 → CancelRejected)', () async {
    when(() => repo.cancelOrder(any(), any())).thenAnswer(
      (_) async => const Left(
        OrdersCancelRejectedFailure('El pedido ya fue confirmado'),
      ),
    );

    final result = await useCase('ord-1', 'x');

    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f, isA<OrdersCancelRejectedFailure>()),
      (_) => fail('esperaba Left'),
    );
  });
}
