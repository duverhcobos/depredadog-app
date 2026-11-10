import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';
import 'package:depredadog_app/features/orders/domain/failures/orders_failure.dart';
import 'package:depredadog_app/features/orders/domain/repositories/i_orders_repository.dart';
import 'package:depredadog_app/features/orders/domain/use_cases/get_order_detail_use_case.dart';

class MockOrdersRepository extends Mock implements IOrdersRepository {}

void main() {
  late MockOrdersRepository repo;
  late GetOrderDetailUseCase useCase;

  final order = CustomerOrder(
    id: 'ord-1',
    serviceType: OrderServiceType.delivery,
    status: OrderStatus.preparing,
    items: const [],
    paymentMethod: OrderPaymentMethod.nequi,
    paymentStatus: OrderPaymentStatus.paid,
    subtotal: 14000,
    deliveryFee: 0,
    placedAt: DateTime(2026, 11, 8, 12, 40),
  );

  setUp(() {
    repo = MockOrdersRepository();
    useCase = GetOrderDetailUseCase(repo);
  });

  test('delegación: mismo id al repo y devuelve su Either', () async {
    when(() => repo.getOrderDetail('ord-1'))
        .thenAnswer((_) async => Right(order));

    final result = await useCase('ord-1');

    expect(result, Right<OrdersFailure, CustomerOrder>(order));
    verify(() => repo.getOrderDetail('ord-1')).called(1);
  });

  test('el Left del repo viaja sin tocar (404 ajeno → server)', () async {
    when(() => repo.getOrderDetail(any()))
        .thenAnswer((_) async => const Left(OrdersServerFailure('not found')));

    final result = await useCase('ord-x');

    expect(result.isLeft(), isTrue);
  });
}
