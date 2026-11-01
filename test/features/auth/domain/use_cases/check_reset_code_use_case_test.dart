import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/check_reset_code_use_case.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late MockAuthRepository repository;
  late CheckResetCodeUseCase useCase;

  setUp(() {
    repository = MockAuthRepository();
    useCase = CheckResetCodeUseCase(repository);
  });

  void stubCheck(Future<Either<AuthFailure, void>> Function() answer) => when(
    () => repository.checkResetCode(
      email: any(named: 'email'),
      code: any(named: 'code'),
    ),
  ).thenAnswer((_) => answer());

  group('CheckResetCodeUseCase', () {
    test('delega al repositorio con los mismos argumentos (Right)', () async {
      stubCheck(() async => const Right(null));

      final result = await useCase(
        email: 'ana@ejemplo.com',
        code: '123456',
      );

      expect(result, const Right<AuthFailure, void>(null));
      verify(
        () => repository.checkResetCode(
          email: 'ana@ejemplo.com',
          code: '123456',
        ),
      ).called(1);
    });

    test('propaga el Left del repositorio sin transformarlo', () async {
      stubCheck(() async => const Left(InvalidCodeFailure()));

      final result = await useCase(
        email: 'ana@ejemplo.com',
        code: '123456',
      );

      expect(result, const Left<AuthFailure, void>(InvalidCodeFailure()));
    });
  });
}
