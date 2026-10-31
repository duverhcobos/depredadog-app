import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/restore_session_use_case.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late MockAuthRepository repository;
  late RestoreSessionUseCase useCase;

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
    useCase = RestoreSessionUseCase(repository);
  });

  group('RestoreSessionUseCase', () {
    test('delega al repositorio y propaga el Right (sesión válida)', () async {
      when(() => repository.restoreSession())
          .thenAnswer((_) async => const Right(user));

      final result = await useCase();

      expect(result, const Right<AuthFailure, User>(user));
      verify(() => repository.restoreSession()).called(1);
    });

    test('propaga el Left del repositorio sin transformarlo', () async {
      when(() => repository.restoreSession())
          .thenAnswer((_) async => const Left(NoStoredSessionFailure()));

      final result = await useCase();

      expect(result, const Left<AuthFailure, User>(NoStoredSessionFailure()));
    });
  });
}
