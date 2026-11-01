import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/reset_password_use_case.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late MockAuthRepository repository;
  late ResetPasswordUseCase useCase;

  const user = User(
    id: 'u1',
    email: 'ana@ejemplo.com',
    firstName: 'Ana',
    firstLastName: 'Pérez',
    role: 'customer',
    status: 'active',
  );

  setUp(() {
    repository = MockAuthRepository();
    useCase = ResetPasswordUseCase(repository);
  });

  void stubReset(Future<Either<AuthFailure, User>> Function() answer) => when(
    () => repository.resetPassword(
      email: any(named: 'email'),
      code: any(named: 'code'),
      newPassword: any(named: 'newPassword'),
    ),
  ).thenAnswer((_) => answer());

  group('ResetPasswordUseCase', () {
    test('delega al repositorio con los mismos argumentos (Right)', () async {
      stubReset(() async => const Right(user));

      final result = await useCase(
        email: 'ana@ejemplo.com',
        code: '123456',
        newPassword: 'nuevaClave123',
      );

      expect(result, const Right<AuthFailure, User>(user));
      verify(
        () => repository.resetPassword(
          email: 'ana@ejemplo.com',
          code: '123456',
          newPassword: 'nuevaClave123',
        ),
      ).called(1);
    });

    test('propaga el Left del repositorio sin transformarlo', () async {
      stubReset(() async => const Left(InvalidCodeFailure()));

      final result = await useCase(
        email: 'ana@ejemplo.com',
        code: '123456',
        newPassword: 'nuevaClave123',
      );

      expect(result, const Left<AuthFailure, User>(InvalidCodeFailure()));
    });
  });
}
