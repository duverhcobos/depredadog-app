import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/core/auth/auth_session.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/login_use_case.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/login_cubit.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/login_state.dart';
import 'package:depredadog_app/features/auth/presentation/inputs/login_inputs.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}

void main() {
  late MockLoginUseCase useCase;
  late AuthSession authSession;

  const user = User(
    id: 'u1',
    email: 'test@depredadog.com',
    firstName: 'Test',
    lastName: 'User',
    role: 'customer',
    status: 'active',
  );

  const validSeed = LoginState(
    email: EmailInput.dirty('test@depredadog.com'),
    password: PasswordInput.dirty('secreto1'),
  );

  setUp(() {
    useCase = MockLoginUseCase();
    authSession = AuthSession();
  });

  LoginCubit buildCubit() =>
      LoginCubit(loginUseCase: useCase, authSession: authSession);

  void stubLogin(Either<AuthFailure, User> result) => when(
    () => useCase(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) async => result);

  group('LoginCubit.submit', () {
    blocTest<LoginCubit, LoginState>(
      'formulario inválido: failure + errores visibles → initial, sin llamar al use case',
      build: buildCubit,
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<LoginState>(),
        isA<LoginState>()
            .having((s) => s.status, 'status', LoginStatus.failure)
            .having((s) => s.showEmailError, 'showEmailError', isTrue)
            .having((s) => s.showPasswordError, 'showPasswordError', isTrue),
        isA<LoginState>().having(
          (s) => s.status,
          'status',
          LoginStatus.initial,
        ),
      ],
      verify: (_) {
        verifyNever(
          () => useCase(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
        expect(authSession.isAuthenticated, isFalse);
      },
    );

    blocTest<LoginCubit, LoginState>(
      'login correcto: inProgress → success y marca AuthSession',
      build: buildCubit,
      seed: () => validSeed,
      setUp: () => stubLogin(const Right(user)),
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<LoginState>().having(
          (s) => s.status,
          'status',
          LoginStatus.inProgress,
        ),
        isA<LoginState>().having(
          (s) => s.status,
          'status',
          LoginStatus.success,
        ),
      ],
      verify: (_) {
        verify(
          () => useCase(email: 'test@depredadog.com', password: 'secreto1'),
        ).called(1);
        expect(authSession.isAuthenticated, isTrue);
        expect(authSession.currentUser, user);
      },
    );

    blocTest<LoginCubit, LoginState>(
      'login rechazado: inProgress → authError con authFailure → initial',
      build: buildCubit,
      seed: () => validSeed,
      setUp: () => stubLogin(const Left(InvalidCredentialsFailure())),
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<LoginState>().having(
          (s) => s.status,
          'status',
          LoginStatus.inProgress,
        ),
        isA<LoginState>()
            .having((s) => s.status, 'status', LoginStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<InvalidCredentialsFailure>(),
            ),
        isA<LoginState>()
            .having((s) => s.status, 'status', LoginStatus.initial)
            .having((s) => s.authFailure, 'authFailure', isNull),
      ],
      verify: (_) => expect(authSession.isAuthenticated, isFalse),
    );
  });
}
