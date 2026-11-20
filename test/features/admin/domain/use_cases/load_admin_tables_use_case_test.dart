import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_table.dart';
import 'package:depredadog_app/features/admin/domain/failures/admin_failure.dart';
import 'package:depredadog_app/features/admin/domain/repositories/i_admin_repository.dart';
import 'package:depredadog_app/features/admin/domain/use_cases/load_admin_tables_use_case.dart';

class MockAdminRepository extends Mock implements IAdminRepository {}

void main() {
  late MockAdminRepository repo;
  late LoadAdminTablesUseCase useCase;

  const mesas = [
    AdminTable(
      id: 't-1',
      label: 'Mesa 1',
      isActive: true,
      activeOrderNumber: null,
    ),
    AdminTable(
      id: 't-3',
      label: 'Mesa 3',
      isActive: true,
      activeOrderNumber: 7,
    ),
  ];

  setUp(() {
    repo = MockAdminRepository();
    useCase = LoadAdminTablesUseCase(repo);
  });

  test('éxito → Right con las mesas del repo (passthrough §042)', () async {
    when(() => repo.getTables()).thenAnswer((_) async => const Right(mesas));

    final result = await useCase();

    expect(result, const Right<AdminFailure, List<AdminTable>>(mesas));
    verify(() => repo.getTables()).called(1);
  });

  test('fallo → Left del repo viaja intacto (offline/server)', () async {
    when(
      () => repo.getTables(),
    ).thenAnswer((_) async => const Left(AdminOfflineFailure()));

    final result = await useCase();

    expect(
      result,
      const Left<AdminFailure, List<AdminTable>>(AdminOfflineFailure()),
    );
  });
}
