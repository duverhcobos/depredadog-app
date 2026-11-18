import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/domain/failures/admin_failure.dart';
import 'package:depredadog_app/features/admin/domain/repositories/i_admin_repository.dart';
import 'package:depredadog_app/features/admin/domain/use_cases/update_admin_order_status_use_case.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';

class MockAdminRepository extends Mock implements IAdminRepository {}

void main() {
  late MockAdminRepository repo;
  late UpdateAdminOrderStatusUseCase useCase;

  AdminOrder order() => AdminOrder(
    id: 'adm-1',
    channel: AdminOrderChannel.online,
    serviceType: AdminServiceType.delivery,
    status: OrderStatus.confirmed,
    items: const [],
    paymentMethod: AdminPaymentMethod.cash,
    paymentStatus: OrderPaymentStatus.paid,
    subtotal: 14000,
    deliveryFee: 0,
    placedAt: DateTime(2026, 11, 8, 12, 40),
  );

  setUp(() {
    repo = MockAdminRepository();
    useCase = UpdateAdminOrderStatusUseCase(repo);
  });

  test('Right: passthrough al repo con `to` + `cancelReason` intactos '
      '— el use case no conoce la matriz, solo reenvía (§040)', () async {
    final expected = order();
    when(
      () => repo.updateOrderStatus(
        'adm-1',
        to: 'cancelled',
        cancelReason: 'se acabó el pan',
      ),
    ).thenAnswer((_) async => Right(expected));

    final result = await useCase(
      'adm-1',
      to: 'cancelled',
      cancelReason: 'se acabó el pan',
    );

    expect(result, Right<AdminFailure, AdminOrder>(expected));
    verify(
      () => repo.updateOrderStatus(
        'adm-1',
        to: 'cancelled',
        cancelReason: 'se acabó el pan',
      ),
    ).called(1);
  });

  test('Right: sin cancelReason el named viaja en null (avance '
      'normal — el backend solo lo lee con to=cancelled)', () async {
    final expected = order();
    when(
      () => repo.updateOrderStatus(
        'adm-1',
        to: 'confirmed',
        cancelReason: any(named: 'cancelReason'),
      ),
    ).thenAnswer((_) async => Right(expected));

    final result = await useCase('adm-1', to: 'confirmed');

    expect(result, Right<AdminFailure, AdminOrder>(expected));
    verify(
      () => repo.updateOrderStatus(
        'adm-1',
        to: 'confirmed',
        cancelReason: null,
      ),
    ).called(1);
  });

  test('Left: la failure del repo se propaga sin tocarla — 409 '
      'conflicto y offline por el mismo canal', () async {
    when(
      () => repo.updateOrderStatus(
        'adm-1',
        to: 'confirmed',
        cancelReason: any(named: 'cancelReason'),
      ),
    ).thenAnswer(
      (_) async => const Left(AdminConflictFailure('INVALID_STATUS_TRANSITION')),
    );

    final result = await useCase('adm-1', to: 'confirmed');

    expect(
      result,
      const Left<AdminFailure, AdminOrder>(
        AdminConflictFailure('INVALID_STATUS_TRANSITION'),
      ),
    );

    when(
      () => repo.updateOrderStatus(
        'adm-9',
        to: 'ready',
        cancelReason: any(named: 'cancelReason'),
      ),
    ).thenAnswer((_) async => const Left(AdminOfflineFailure()));

    final result2 = await useCase('adm-9', to: 'ready');

    expect(
      result2,
      const Left<AdminFailure, AdminOrder>(AdminOfflineFailure()),
    );
  });
}
