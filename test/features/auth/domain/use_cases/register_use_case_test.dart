import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/register_use_case.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late MockAuthRepository repository;
  late RegisterUseCase useCase;

  const user = User(
    id: 'u1',
    email: 'ana@ejemplo.com',
    firstName: 'Ana',
    secondName: 'María',
    firstLastName: 'Pérez',
    secondLastName: 'Gómez',
    role: 'customer',
    status: 'pending_verification',
  );

  setUp(() {
    repository = MockAuthRepository();
    useCase = RegisterUseCase(repository);
  });

  void stubRegister(Future<Either<AuthFailure, User>> Function() answer) =>
      when(
        () => repository.register(
          email: any(named: 'email'),
          password: any(named: 'password'),
          firstName: any(named: 'firstName'),
          secondName: any(named: 'secondName'),
          firstLastName: any(named: 'firstLastName'),
          secondLastName: any(named: 'secondLastName'),
          phone: any(named: 'phone'),
        ),
      ).thenAnswer((_) => answer());

  group('RegisterUseCase', () {
    test('delega al repositorio con los mismos argumentos (Right)', () async {
      stubRegister(() async => const Right(user));

      final result = await useCase(
        email: 'ana@ejemplo.com',
        password: 'secreto123',
        firstName: 'Ana',
        secondName: 'María',
        firstLastName: 'Pérez',
        secondLastName: 'Gómez',
        phone: '3001234567',
      );

      expect(result, const Right<AuthFailure, User>(user));
      verify(
        () => repository.register(
          email: 'ana@ejemplo.com',
          password: 'secreto123',
          firstName: 'Ana',
          secondName: 'María',
          firstLastName: 'Pérez',
          secondLastName: 'Gómez',
          phone: '3001234567',
        ),
      ).called(1);
    });

    test('propaga el Left del repositorio sin transformarlo', () async {
      stubRegister(
        () async => const Left(EmailAlreadyRegisteredFailure()),
      );

      final result = await useCase(
        email: 'ana@ejemplo.com',
        password: 'secreto123',
        firstName: 'Ana',
        firstLastName: 'Pérez',
      );

      expect(
        result,
        const Left<AuthFailure, User>(EmailAlreadyRegisteredFailure()),
      );
    });
  });
}
