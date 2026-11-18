import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/domain/failures/admin_failure.dart';
import 'package:depredadog_app/features/admin/domain/repositories/i_admin_repository.dart';
import 'package:depredadog_app/features/admin/domain/use_cases/confirm_admin_order_payment_use_case.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';

class MockAdminRepository extends Mock implements IAdminRepository {}

void main() {
  late MockAdminRepository repo;
  late ConfirmAdminOrderPaymentUseCase useCase;

  AdminOrder order() => AdminOrder(
    id: 'adm-1',
    channel: AdminOrderChannel.presencial,
    serviceType: AdminServiceType.pickup,
    status: OrderStatus.confirmed,
    items: const [],
    paymentMethod: AdminPaymentMethod.cash,
    paymentStatus: OrderPaymentStatus.paid,
    subtotal: 18000,
    deliveryFee: 0,
    placedAt: DateTime(2026, 11, 8, 12, 40),
  );

  setUp(() {
    repo = MockAdminRepository();
    useCase = ConfirmAdminOrderPaymentUseCase(repo);
  });

  test('Right: passthrough al repo con el orderId — el use case no '
      'conoce la matriz del §022, solo reenvía el claim (§041)', () async {
    final expected = order();
    when(
      () => repo.confirmOrderPayment('adm-1'),
    ).thenAnswer((_) async => Right(expected));

    final result = await useCase('adm-1');

    expect(result, Right<AdminFailure, AdminOrder>(expected));
    verify(() => repo.confirmOrderPayment('adm-1')).called(1);
  });

  test('Left: la failure del repo se propaga sin tocarla — 409 '
      'PAYMENT_NOT_CONFIRMABLE y offline por el mismo canal', () async {
    when(
      () => repo.confirmOrderPayment('adm-1'),
    ).thenAnswer(
      (_) async => const Left(AdminConflictFailure('PAYMENT_NOT_CONFIRMABLE')),
    );

    final result = await useCase('adm-1');

    expect(
      result,
      const Left<AdminFailure, AdminOrder>(
        AdminConflictFailure('PAYMENT_NOT_CONFIRMABLE'),
      ),
    );

    when(
      () => repo.confirmOrderPayment('adm-9'),
    ).thenAnswer((_) async => const Left(AdminOfflineFailure()));

    final result2 = await useCase('adm-9');

    expect(
      result2,
      const Left<AdminFailure, AdminOrder>(AdminOfflineFailure()),
    );
  });
}
