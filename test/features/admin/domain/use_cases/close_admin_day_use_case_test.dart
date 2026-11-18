import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_day_close.dart';
import 'package:depredadog_app/features/admin/domain/failures/admin_failure.dart';
import 'package:depredadog_app/features/admin/domain/repositories/i_admin_repository.dart';
import 'package:depredadog_app/features/admin/domain/use_cases/close_admin_day_use_case.dart';

class MockAdminRepository extends Mock implements IAdminRepository {}

void main() {
  late MockAdminRepository repo;
  late CloseAdminDayUseCase useCase;

  const closed = AdminDayClose(
    orderCount: 3,
    totalAmount: 65000,
    byMethod: [
      AdminDayCloseMethod(method: 'cash', count: 1, amount: 26000),
      AdminDayCloseMethod(method: 'transfer', count: 2, amount: 39000),
    ],
    cancelledCount: 3,
    cancelledAmount: 85000,
  );

  setUp(() {
    repo = MockAdminRepository();
    useCase = CloseAdminDayUseCase(repo);
  });

  test('Right: passthrough al repo — el snapshot persistido del '
      'cierre viaja intacto (§041)', () async {
    when(() => repo.closeDay()).thenAnswer((_) async => const Right(closed));

    final result = await useCase();

    expect(result, const Right<AdminFailure, AdminDayClose>(closed));
    verify(() => repo.closeDay()).called(1);
  });

  test('Left: la failure del repo se propaga sin tocarla — offline '
      'y servidor por el mismo canal', () async {
    when(
      () => repo.closeDay(),
    ).thenAnswer((_) async => const Left(AdminOfflineFailure()));

    final result = await useCase();

    expect(
      result,
      const Left<AdminFailure, AdminDayClose>(AdminOfflineFailure()),
    );

    when(
      () => repo.closeDay(),
    ).thenAnswer((_) async => const Left(AdminServerFailure('boom')));

    final result2 = await useCase();

    expect(
      result2,
      const Left<AdminFailure, AdminDayClose>(AdminServerFailure('boom')),
    );
  });
}
