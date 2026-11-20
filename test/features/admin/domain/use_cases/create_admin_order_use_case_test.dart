import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_new_order_draft.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/domain/failures/admin_failure.dart';
import 'package:depredadog_app/features/admin/domain/repositories/i_admin_repository.dart';
import 'package:depredadog_app/features/admin/domain/use_cases/create_admin_order_use_case.dart';
import 'package:depredadog_app/features/orders/domain/entities/customer_order.dart';

class MockAdminRepository extends Mock implements IAdminRepository {}

void main() {
  late MockAdminRepository repo;
  late CreateAdminOrderUseCase useCase;

  const draft = AdminNewOrderDraft(
    serviceType: AdminServiceType.dineIn,
    tableId: 't-2',
    paymentMethod: AdminPaymentMethod.cash,
    items: [],
  );

  final creada = AdminOrder(
    id: 'ord-nueva',
    channel: AdminOrderChannel.presencial,
    serviceType: AdminServiceType.dineIn,
    status: OrderStatus.confirmed,
    items: const [],
    paymentMethod: AdminPaymentMethod.cash,
    paymentStatus: OrderPaymentStatus.pending,
    subtotal: 14000,
    deliveryFee: 0,
    placedAt: DateTime(2026, 11, 8, 12, 40),
    tableLabel: 'Mesa 2',
    orderNumber: 8,
  );

  setUpAll(() {
    registerFallbackValue(draft);
  });

  setUp(() {
    repo = MockAdminRepository();
    useCase = CreateAdminOrderUseCase(repo);
  });

  test('éxito → Right con la orden creada y el draft viaja al repo '
      'intacto (passthrough §042)', () async {
    when(
      () => repo.createInPersonOrder(any()),
    ).thenAnswer((_) async => Right(creada));

    final result = await useCase(draft);

    result.fold(
      (_) => fail('se esperaba Right con la orden creada'),
      (o) => expect(o.orderNumber, 8),
    );
    verify(() => repo.createInPersonOrder(draft)).called(1);
  });

  test('fallo → Left del repo viaja intacto con el errorCode '
      '(TABLE_NOT_FOUND → resync en el cubit)', () async {
    when(() => repo.createInPersonOrder(any())).thenAnswer(
      (_) async => const Left(
        AdminServerFailure('Table not found', errorCode: 'TABLE_NOT_FOUND'),
      ),
    );

    final result = await useCase(draft);

    expect(
      result,
      const Left<AdminFailure, AdminOrder>(
        AdminServerFailure('Table not found', errorCode: 'TABLE_NOT_FOUND'),
      ),
    );
  });
}
