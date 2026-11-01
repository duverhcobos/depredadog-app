import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/forgot_password_use_case.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late MockAuthRepository repository;
  late ForgotPasswordUseCase useCase;

  setUp(() {
    repository = MockAuthRepository();
    useCase = ForgotPasswordUseCase(repository);
  });

  void stubForgot(Future<Either<AuthFailure, void>> Function() answer) =>
      when(() => repository.forgotPassword(email: any(named: 'email')))
          .thenAnswer((_) => answer());

  group('ForgotPasswordUseCase', () {
    test('delega al repositorio con los mismos argumentos (Right)', () async {
      stubForgot(() async => const Right(null));

      final result = await useCase(email: 'ana@ejemplo.com');

      expect(result, const Right<AuthFailure, void>(null));
      verify(() => repository.forgotPassword(email: 'ana@ejemplo.com'))
          .called(1);
    });

    test('propaga el Left del repositorio sin transformarlo', () async {
      stubForgot(() async => const Left(TooManyAttemptsFailure()));

      final result = await useCase(email: 'ana@ejemplo.com');

      expect(
        result,
        const Left<AuthFailure, void>(TooManyAttemptsFailure()),
      );
    });
  });
}
