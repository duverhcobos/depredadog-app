import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/domain/failures/admin_failure.dart';
import 'package:depredadog_app/features/admin/domain/repositories/i_admin_repository.dart';
import 'package:depredadog_app/features/admin/domain/use_cases/load_admin_queue_use_case.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';

class MockAdminRepository extends Mock implements IAdminRepository {}

void main() {
  late MockAdminRepository repo;
  late LoadAdminQueueUseCase useCase;

  AdminOrder order(String id) => AdminOrder(
    id: id,
    channel: AdminOrderChannel.online,
    serviceType: AdminServiceType.delivery,
    status: OrderStatus.received,
    items: const [],
    paymentMethod: AdminPaymentMethod.cash,
    paymentStatus: OrderPaymentStatus.pending,
    subtotal: 14000,
    deliveryFee: 0,
    placedAt: DateTime(2026, 11, 8, 12, 40),
  );

  setUp(() {
    repo = MockAdminRepository();
    useCase = LoadAdminQueueUseCase(repo);
  });

  test('ambos GET ok → cada pierna Right (cola activa + página 1 del '
      'historial en paralelo)', () async {
    final active = [order('adm-1')];
    final page = AdminHistoryPage(items: [order('adm-9')], total: 7);
    when(() => repo.getActiveOrders()).thenAnswer((_) async => Right(active));
    when(() => repo.getHistoryOrders(1)).thenAnswer((_) async => Right(page));

    final result = await useCase();

    expect(result.active, Right<AdminFailure, List<AdminOrder>>(active));
    expect(result.history, Right<AdminFailure, AdminHistoryPage>(page));
    verify(() => repo.getActiveOrders()).called(1);
    verify(() => repo.getHistoryOrders(1)).called(1);
  });

  test('una pierna falla NO tumba la otra (Either independientes — '
      'la cola puede llegar aunque el historial falle)', () async {
    when(repo.getActiveOrders)
        .thenAnswer((_) async => const Left(AdminServerFailure('boom')));
    when(() => repo.getHistoryOrders(1)).thenAnswer(
      (_) async => Right(AdminHistoryPage(items: const [], total: 0)),
    );

    final result = await useCase();

    expect(result.active.isLeft(), isTrue);
    expect(result.history.isRight(), isTrue);

    when(() => repo.getActiveOrders())
        .thenAnswer((_) async => Right([order('adm-1')]));
    when(() => repo.getHistoryOrders(any()))
        .thenAnswer((_) async => const Left(AdminOfflineFailure()));

    final result2 = await useCase();

    expect(result2.active.isRight(), isTrue);
    expect(result2.history.isLeft(), isTrue);
  });
}
