import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/google_sign_in_use_case.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late MockAuthRepository repository;
  late GoogleSignInUseCase useCase;

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
    useCase = GoogleSignInUseCase(repository);
  });

  void stubSignInWithGoogle(Future<Either<AuthFailure, User?>> Function() answer) =>
      when(() => repository.signInWithGoogle()).thenAnswer((_) => answer());

  group('GoogleSignInUseCase', () {
    test('delega al repositorio (Right con usuario)', () async {
      stubSignInWithGoogle(() async => const Right(user));

      final result = await useCase();

      expect(result, const Right<AuthFailure, User?>(user));
      verify(() => repository.signInWithGoogle()).called(1);
    });

    test('cancel del picker: propaga Right(null) sin transformarlo', () async {
      stubSignInWithGoogle(() async => const Right(null));

      final result = await useCase();

      expect(result, const Right<AuthFailure, User?>(null));
    });

    test('propaga el Left del repositorio sin transformarlo', () async {
      stubSignInWithGoogle(
        () async => const Left(InvalidCredentialsFailure()),
      );

      final result = await useCase();

      expect(
        result,
        const Left<AuthFailure, User?>(InvalidCredentialsFailure()),
      );
    });
  });
}
