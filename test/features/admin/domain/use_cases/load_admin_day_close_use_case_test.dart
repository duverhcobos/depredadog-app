import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_day_close.dart';
import 'package:depredadog_app/features/admin/domain/failures/admin_failure.dart';
import 'package:depredadog_app/features/admin/domain/repositories/i_admin_repository.dart';
import 'package:depredadog_app/features/admin/domain/use_cases/load_admin_day_close_use_case.dart';

class MockAdminRepository extends Mock implements IAdminRepository {}

void main() {
  late MockAdminRepository repo;
  late LoadAdminDayCloseUseCase useCase;

  const preview = AdminDayClose(
    orderCount: 2,
    totalAmount: 44000,
    byMethod: [
      AdminDayCloseMethod(method: 'cash', count: 1, amount: 28000),
      AdminDayCloseMethod(method: 'nequi', count: 1, amount: 16000),
    ],
    cancelledCount: 1,
    cancelledAmount: 16000,
  );

  setUp(() {
    repo = MockAdminRepository();
    useCase = LoadAdminDayCloseUseCase(repo);
  });

  test('Right: passthrough al repo — el snapshot del servidor viaja '
      'intacto (§041)', () async {
    when(
      () => repo.getDayClosePreview(),
    ).thenAnswer((_) async => const Right(preview));

    final result = await useCase();

    expect(result, const Right<AdminFailure, AdminDayClose>(preview));
    verify(() => repo.getDayClosePreview()).called(1);
  });

  test('Left: la failure del repo se propaga sin tocarla — offline '
      'y servidor por el mismo canal', () async {
    when(
      () => repo.getDayClosePreview(),
    ).thenAnswer((_) async => const Left(AdminOfflineFailure()));

    final result = await useCase();

    expect(
      result,
      const Left<AdminFailure, AdminDayClose>(AdminOfflineFailure()),
    );

    when(
      () => repo.getDayClosePreview(),
    ).thenAnswer((_) async => const Left(AdminServerFailure('boom')));

    final result2 = await useCase();

    expect(
      result2,
      const Left<AdminFailure, AdminDayClose>(AdminServerFailure('boom')),
    );
  });
}
