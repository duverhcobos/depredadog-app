import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';
import 'package:depredadog_app/features/orders/domain/failures/orders_failure.dart';
import 'package:depredadog_app/features/orders/domain/repositories/i_orders_repository.dart';
import 'package:depredadog_app/features/orders/domain/use_cases/load_orders_use_case.dart';

class MockOrdersRepository extends Mock implements IOrdersRepository {}

void main() {
  late MockOrdersRepository repo;
  late LoadOrdersUseCase useCase;

  CustomerOrder order(String id) => CustomerOrder(
    id: id,
    serviceType: OrderServiceType.pickup,
    status: OrderStatus.received,
    items: const [],
    paymentMethod: OrderPaymentMethod.nequi,
    paymentStatus: OrderPaymentStatus.pending,
    subtotal: 14000,
    deliveryFee: 0,
    placedAt: DateTime(2026, 11, 8, 12, 40),
  );

  setUp(() {
    repo = MockOrdersRepository();
    useCase = LoadOrdersUseCase(repo);
  });

  test('ambos GET ok → cada pierna Right (activos + page 1 del '
      'historial en paralelo)', () async {
    final active = [order('ord-1')];
    final page = OrdersHistoryPage(items: [order('ord-9')], total: 7);
    when(() => repo.getActiveOrders()).thenAnswer((_) async => Right(active));
    when(() => repo.getHistoryOrders(1)).thenAnswer((_) async => Right(page));

    final result = await useCase();

    expect(result.active, Right<OrdersFailure, List<CustomerOrder>>(active));
    expect(result.history, Right<OrdersFailure, OrdersHistoryPage>(page));
    verify(() => repo.getActiveOrders()).called(1);
    verify(() => repo.getHistoryOrders(1)).called(1);
  });

  test('una pierna falla NO tumba la otra (Either independientes)', () async {
    when(repo.getActiveOrders)
        .thenAnswer((_) async => const Left(OrdersServerFailure('boom')));
    when(() => repo.getHistoryOrders(1)).thenAnswer(
      (_) async => Right(OrdersHistoryPage(items: const [], total: 0)),
    );

    final result = await useCase();

    expect(result.active.isLeft(), isTrue);
    expect(result.history.isRight(), isTrue);

    when(() => repo.getActiveOrders())
        .thenAnswer((_) async => Right([order('ord-1')]));
    when(() => repo.getHistoryOrders(any()))
        .thenAnswer((_) async => const Left(OrdersOfflineFailure()));

    final result2 = await useCase();

    expect(result2.active.isRight(), isTrue);
    expect(result2.history.isLeft(), isTrue);
  });
}
