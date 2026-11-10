import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/checkout/domain/entities/placed_order.dart';
import 'package:depredadog_app/features/checkout/domain/failures/checkout_failure.dart';
import 'package:depredadog_app/features/checkout/domain/repositories/i_checkout_repository.dart';
import 'package:depredadog_app/features/checkout/domain/use_cases/create_order_params.dart';
import 'package:depredadog_app/features/checkout/domain/use_cases/create_order_use_case.dart';

class MockCheckoutRepository extends Mock implements ICheckoutRepository {}

void main() {
  late MockCheckoutRepository repo;
  late CreateOrderUseCase useCase;

  const placed = PlacedOrder(
    id: 'o-1',
    orderNumber: 7,
    status: 'pending',
    total: 14000,
  );

  const params = CreateOrderParams(
    serviceType: 'delivery',
    paymentMethod: 'cash',
    clientRequestId: 'req-1',
    items: [OrderItemInput(productId: 'p-1', quantity: 2)],
  );

  setUpAll(() {
    registerFallbackValue(params);
  });

  setUp(() {
    repo = MockCheckoutRepository();
    useCase = CreateOrderUseCase(repo);
  });

  test('passthrough: el MISMO comando llega al repo y su Either '
      'devuelve tal cual', () async {
    when(() => repo.createOrder(params))
        .thenAnswer((_) async => const Right(placed));

    final result = await useCase(params);

    expect(result, const Right<CheckoutFailure, PlacedOrder>(placed));
    verify(() => repo.createOrder(params)).called(1);
  });

  test('el Left del repo viaja sin tocar', () async {
    when(() => repo.createOrder(any())).thenAnswer(
      (_) async => const Left(
        CheckoutOrderRejectedFailure(
          'El local está cerrado ahora',
          code: OrderRejection.storeClosed,
        ),
      ),
    );

    final result = await useCase(params);

    expect(
      result,
      const Left<CheckoutFailure, PlacedOrder>(
        CheckoutOrderRejectedFailure(
          'El local está cerrado ahora',
          code: OrderRejection.storeClosed,
        ),
      ),
    );
  });
}
