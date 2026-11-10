import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/orders/domain/failures/orders_failure.dart';
import 'package:depredadog_app/features/orders/domain/repositories/i_orders_repository.dart';
import 'package:depredadog_app/features/orders/domain/use_cases/load_more_history_use_case.dart';

class MockOrdersRepository extends Mock implements IOrdersRepository {}

void main() {
  late MockOrdersRepository repo;
  late LoadMoreHistoryUseCase useCase;

  setUp(() {
    repo = MockOrdersRepository();
    useCase = LoadMoreHistoryUseCase(repo);
  });

  test('delegación: mismo page al repo y devuelve su Either', () async {
    final page = OrdersHistoryPage(items: const [], total: 25);
    when(() => repo.getHistoryOrders(3)).thenAnswer((_) async => Right(page));

    final result = await useCase(3);

    expect(result, Right<OrdersFailure, OrdersHistoryPage>(page));
    verify(() => repo.getHistoryOrders(3)).called(1);
  });

  test('el Left del repo viaja sin tocar', () async {
    when(() => repo.getHistoryOrders(any()))
        .thenAnswer((_) async => const Left(OrdersOfflineFailure()));

    final result = await useCase(2);

    expect(result.isLeft(), isTrue);
  });
}
