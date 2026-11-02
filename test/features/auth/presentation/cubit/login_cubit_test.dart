import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/core/auth/auth_session.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/google_sign_in_use_case.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/login_use_case.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/login_cubit.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/login_state.dart';
import 'package:depredadog_app/features/auth/presentation/inputs/login_inputs.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockGoogleSignInUseCase extends Mock implements GoogleSignInUseCase {}

void main() {
  late MockLoginUseCase useCase;
  late MockGoogleSignInUseCase googleUseCase;
  late AuthSession authSession;

  const user = User(
    id: 'u1',
    email: 'test@depredadog.com',
    firstName: 'Test',
    firstLastName: 'User',
    role: 'customer',
    status: 'active',
  );

  const validSeed = LoginState(
    email: EmailInput.dirty('test@depredadog.com'),
    password: PasswordInput.dirty('secreto1'),
  );

  setUp(() {
    useCase = MockLoginUseCase();
    googleUseCase = MockGoogleSignInUseCase();
    authSession = AuthSession();
  });

  LoginCubit buildCubit() => LoginCubit(
    loginUseCase: useCase,
    googleSignInUseCase: googleUseCase,
    authSession: authSession,
  );

  void stubLogin(Either<AuthFailure, User> result) => when(
    () => useCase(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) async => result);

  void stubGoogle(Either<AuthFailure, User?> result) =>
      when(() => googleUseCase()).thenAnswer((_) async => result);

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

  group('LoginCubit.signInWithGoogle', () {
    blocTest<LoginCubit, LoginState>(
      'éxito: inProgress → success marcado isGoogleAuth y marca AuthSession',
      build: buildCubit,
      setUp: () => stubGoogle(const Right(user)),
      act: (cubit) => cubit.signInWithGoogle(),
      expect: () => [
        isA<LoginState>().having(
          (s) => s.status,
          'status',
          LoginStatus.inProgress,
        ),
        isA<LoginState>()
            .having((s) => s.status, 'status', LoginStatus.success)
            .having((s) => s.isGoogleAuth, 'isGoogleAuth', isTrue),
      ],
      verify: (_) {
        verify(() => googleUseCase()).called(1);
        expect(authSession.isAuthenticated, isTrue);
        expect(authSession.currentUser, user);
      },
    );

    blocTest<LoginCubit, LoginState>(
      'cancel del picker (Right null): inProgress → initial en silencio, '
      'sin authFailure ni sesión',
      build: buildCubit,
      setUp: () => stubGoogle(const Right(null)),
      act: (cubit) => cubit.signInWithGoogle(),
      expect: () => [
        isA<LoginState>().having(
          (s) => s.status,
          'status',
          LoginStatus.inProgress,
        ),
        isA<LoginState>()
            .having((s) => s.status, 'status', LoginStatus.initial)
            .having((s) => s.authFailure, 'authFailure', isNull)
            .having((s) => s.isGoogleAuth, 'isGoogleAuth', isFalse),
      ],
      verify: (_) => expect(authSession.isAuthenticated, isFalse),
    );

    blocTest<LoginCubit, LoginState>(
      'error: inProgress → authError con authFailure + isGoogleAuth → '
      'initial limpio',
      build: buildCubit,
      setUp: () => stubGoogle(const Left(UnknownAuthFailure('SDK boom'))),
      act: (cubit) => cubit.signInWithGoogle(),
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
              isA<UnknownAuthFailure>(),
            )
            .having((s) => s.isGoogleAuth, 'isGoogleAuth', isTrue),
        isA<LoginState>()
            .having((s) => s.status, 'status', LoginStatus.initial)
            .having((s) => s.authFailure, 'authFailure', isNull)
            .having((s) => s.isGoogleAuth, 'isGoogleAuth', isFalse),
      ],
      verify: (_) => expect(authSession.isAuthenticated, isFalse),
    );

    blocTest<LoginCubit, LoginState>(
      'durante inProgress no re-emite ni re-llama (doble tap)',
      build: buildCubit,
      seed: () => const LoginState(status: LoginStatus.inProgress),
      act: (cubit) => cubit.signInWithGoogle(),
      expect: () => <LoginState>[],
      verify: (_) => verifyNever(() => googleUseCase()),
    );
  });
}
