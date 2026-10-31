import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/login_use_case.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late MockAuthRepository repository;
  late LoginUseCase useCase;

  const user = User(
    id: 'u1',
    email: 'test@depredadog.com',
    firstName: 'Test',
    firstLastName: 'User',
    role: 'customer',
    status: 'active',
  );

  setUp(() {
    repository = MockAuthRepository();
    useCase = LoginUseCase(repository);
  });

  void stubLogin(Future<Either<AuthFailure, User>> Function() answer) => when(
    () => repository.login(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) => answer());

  group('LoginUseCase', () {
    test('delega al repositorio con los mismos argumentos (Right)', () async {
      stubLogin(() async => const Right(user));

      final result = await useCase(
        email: 'test@depredadog.com',
        password: 'secreto1',
      );

      expect(result, const Right<AuthFailure, User>(user));
      verify(
        () => repository.login(
          email: 'test@depredadog.com',
          password: 'secreto1',
        ),
      ).called(1);
    });

    test('propaga el Left del repositorio sin transformarlo', () async {
      stubLogin(() async => const Left(InvalidCredentialsFailure()));

      final result = await useCase(
        email: 'test@depredadog.com',
        password: 'secreto1',
      );

      expect(
        result,
        const Left<AuthFailure, User>(InvalidCredentialsFailure()),
      );
    });
  });
}
