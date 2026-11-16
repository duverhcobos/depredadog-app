import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/domain/failures/admin_failure.dart';
import 'package:depredadog_app/features/admin/domain/repositories/i_admin_repository.dart';
import 'package:depredadog_app/features/admin/domain/use_cases/get_admin_order_detail_use_case.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';

class MockAdminRepository extends Mock implements IAdminRepository {}

void main() {
  late MockAdminRepository repo;
  late GetAdminOrderDetailUseCase useCase;

  AdminOrder order() => AdminOrder(
    id: 'adm-1',
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
    useCase = GetAdminOrderDetailUseCase(repo);
  });

  test('Right: delega getOrderDetail al repo con el id — la comanda '
      'completa (modifiers) viaja intacta (§039)', () async {
    final expected = order();
    when(
      () => repo.getOrderDetail('adm-1'),
    ).thenAnswer((_) async => Right(expected));

    final result = await useCase('adm-1');

    expect(result, Right<AdminFailure, AdminOrder>(expected));
    verify(() => repo.getOrderDetail('adm-1')).called(1);
    verifyNever(() => repo.getActiveOrders());
    verifyNever(() => repo.getHistoryOrders(any()));
  });

  test('Left: la failure del repo se propaga sin tocarla — offline '
      'y servidor por el mismo canal', () async {
    when(
      () => repo.getOrderDetail('adm-1'),
    ).thenAnswer((_) async => const Left(AdminOfflineFailure()));

    final result = await useCase('adm-1');

    expect(
      result,
      const Left<AdminFailure, AdminOrder>(AdminOfflineFailure()),
    );

    when(
      () => repo.getOrderDetail('adm-9'),
    ).thenAnswer((_) async => const Left(AdminServerFailure('boom')));

    final result2 = await useCase('adm-9');

    expect(
      result2,
      const Left<AdminFailure, AdminOrder>(AdminServerFailure('boom')),
    );
  });
}
