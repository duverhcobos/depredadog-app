import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/auth/auth_session.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/resend_verification_use_case.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/verify_email_use_case.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/verify_email_cubit.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/verify_email_state.dart';
import 'package:depredadog_app/features/auth/presentation/inputs/verify_email_inputs.dart';

class MockVerifyEmailUseCase extends Mock implements VerifyEmailUseCase {}

class MockResendVerificationUseCase extends Mock
    implements ResendVerificationUseCase {}

void main() {
  late MockVerifyEmailUseCase verifyUseCase;
  late MockResendVerificationUseCase resendUseCase;
  late AuthSession authSession;

  const email = 'test@depredadog.com';

  const user = User(
    id: 'u1',
    email: email,
    firstName: 'Test',
    firstLastName: 'User',
    role: 'customer',
    status: 'active',
  );

  const filledSeed = VerifyEmailState(
    email: email,
    code: CodeInput.dirty('123456'),
  );

  setUp(() {
    verifyUseCase = MockVerifyEmailUseCase();
    resendUseCase = MockResendVerificationUseCase();
    authSession = AuthSession();
  });

  VerifyEmailCubit buildCubit() => VerifyEmailCubit(
    email: email,
    verifyEmailUseCase: verifyUseCase,
    resendVerificationUseCase: resendUseCase,
    authSession: authSession,
  );

  void stubVerify(Either<AuthFailure, User> result) => when(
    () => verifyUseCase(
      email: any(named: 'email'),
      code: any(named: 'code'),
    ),
  ).thenAnswer((_) async => result);

  void stubResend(Either<AuthFailure, void> result) =>
      when(() => resendUseCase(email: any(named: 'email')))
          .thenAnswer((_) async => result);

  group('VerifyEmailCubit.submit', () {
    blocTest<VerifyEmailCubit, VerifyEmailState>(
      'código inválido local: failure + showCodeError → initial, sin llamar al use case',
      build: buildCubit,
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<VerifyEmailState>()
            .having((s) => s.status, 'status', VerifyEmailStatus.failure)
            .having((s) => s.showCodeError, 'showCodeError', isTrue),
        isA<VerifyEmailState>().having(
          (s) => s.status,
          'status',
          VerifyEmailStatus.initial,
        ),
      ],
      verify: (_) {
        verifyNever(
          () => verifyUseCase(
            email: any(named: 'email'),
            code: any(named: 'code'),
          ),
        );
        expect(authSession.isAuthenticated, isFalse);
      },
    );

    blocTest<VerifyEmailCubit, VerifyEmailState>(
      'código correcto: inProgress → success y marca AuthSession (auto-login)',
      build: buildCubit,
      seed: () => filledSeed,
      setUp: () => stubVerify(const Right(user)),
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<VerifyEmailState>().having(
          (s) => s.status,
          'status',
          VerifyEmailStatus.inProgress,
        ),
        isA<VerifyEmailState>().having(
          (s) => s.status,
          'status',
          VerifyEmailStatus.success,
        ),
      ],
      verify: (_) {
        verify(() => verifyUseCase(email: email, code: '123456')).called(1);
        expect(authSession.isAuthenticated, isTrue);
        expect(authSession.currentUser, user);
      },
    );

    blocTest<VerifyEmailCubit, VerifyEmailState>(
      'código rechazado (400): inProgress → authError con InvalidCodeFailure',
      build: buildCubit,
      seed: () => filledSeed,
      setUp: () => stubVerify(const Left(InvalidCodeFailure())),
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<VerifyEmailState>().having(
          (s) => s.status,
          'status',
          VerifyEmailStatus.inProgress,
        ),
        isA<VerifyEmailState>()
            .having((s) => s.status, 'status', VerifyEmailStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<InvalidCodeFailure>(),
            ),
      ],
      verify: (_) => expect(authSession.isAuthenticated, isFalse),
    );

    blocTest<VerifyEmailCubit, VerifyEmailState>(
      'rate limit (429): inProgress → authError con TooManyAttemptsFailure',
      build: buildCubit,
      seed: () => filledSeed,
      setUp: () => stubVerify(const Left(TooManyAttemptsFailure())),
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<VerifyEmailState>().having(
          (s) => s.status,
          'status',
          VerifyEmailStatus.inProgress,
        ),
        isA<VerifyEmailState>()
            .having((s) => s.status, 'status', VerifyEmailStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<TooManyAttemptsFailure>(),
            ),
      ],
      verify: (_) => expect(authSession.isAuthenticated, isFalse),
    );
  });

  group('VerifyEmailCubit.resend', () {
    blocTest<VerifyEmailCubit, VerifyEmailState>(
      'reenvío exitoso: limpia el código, resendTick+1 y cooldown 60s',
      build: buildCubit,
      seed: () => filledSeed,
      setUp: () => stubResend(const Right(null)),
      act: (cubit) => cubit.resend(),
      expect: () => [
        isA<VerifyEmailState>().having(
          (s) => s.isResending,
          'isResending',
          isTrue,
        ),
        isA<VerifyEmailState>()
            .having((s) => s.isResending, 'isResending', isFalse)
            .having((s) => s.code.value, 'code', '')
            .having((s) => s.resendTick, 'resendTick', 1)
            .having((s) => s.resendCooldown, 'resendCooldown', 60),
      ],
      verify: (_) => verify(() => resendUseCase(email: email)).called(1),
    );

    blocTest<VerifyEmailCubit, VerifyEmailState>(
      'reenvío fallido (429): authError y el código tipeado se conserva, sin cooldown',
      build: buildCubit,
      seed: () => filledSeed,
      setUp: () => stubResend(const Left(TooManyAttemptsFailure())),
      act: (cubit) => cubit.resend(),
      expect: () => [
        isA<VerifyEmailState>().having(
          (s) => s.isResending,
          'isResending',
          isTrue,
        ),
        isA<VerifyEmailState>()
            .having((s) => s.isResending, 'isResending', isFalse)
            .having((s) => s.status, 'status', VerifyEmailStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<TooManyAttemptsFailure>(),
            )
            // El código viejo sigue válido en el server (el reenvío
            // falló, no se emitió uno nuevo) — se conserva.
            .having((s) => s.code.value, 'code', '123456')
            .having((s) => s.resendCooldown, 'resendCooldown', 0)
            .having((s) => s.resendTick, 'resendTick', 0),
      ],
    );

    blocTest<VerifyEmailCubit, VerifyEmailState>(
      'authError de verify → resend falla: el authError se re-emite '
      '(initial intermedio — el listener del screen vuelve a disparar)',
      build: buildCubit,
      seed: () => filledSeed,
      setUp: () {
        stubVerify(const Left(InvalidCodeFailure()));
        stubResend(const Left(TooManyAttemptsFailure()));
      },
      act: (cubit) async {
        await cubit.submit();
        await cubit.resend();
      },
      expect: () => [
        isA<VerifyEmailState>().having(
          (s) => s.status,
          'status',
          VerifyEmailStatus.inProgress,
        ),
        isA<VerifyEmailState>()
            .having((s) => s.status, 'status', VerifyEmailStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<InvalidCodeFailure>(),
            ),
        // El emit de isResending resetea status a initial — sin esto el
        // segundo authError sería una transición muda para el listener.
        isA<VerifyEmailState>()
            .having((s) => s.isResending, 'isResending', isTrue)
            .having((s) => s.status, 'status', VerifyEmailStatus.initial)
            .having((s) => s.authFailure, 'authFailure', isNull),
        isA<VerifyEmailState>()
            .having((s) => s.isResending, 'isResending', isFalse)
            .having((s) => s.status, 'status', VerifyEmailStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<TooManyAttemptsFailure>(),
            ),
      ],
    );

    blocTest<VerifyEmailCubit, VerifyEmailState>(
      'submit durante isResending no dispara (carrera resend↔submit)',
      build: buildCubit,
      seed: () => const VerifyEmailState(
        email: email,
        code: CodeInput.dirty('123456'),
        isResending: true,
      ),
      act: (cubit) => cubit.submit(),
      expect: () => <VerifyEmailState>[],
      verify: (_) => verifyNever(
        () => verifyUseCase(
          email: any(named: 'email'),
          code: any(named: 'code'),
        ),
      ),
    );

    blocTest<VerifyEmailCubit, VerifyEmailState>(
      'reenvío fallido (sin red): authError con NoConnectionFailure, código conservado',
      build: buildCubit,
      seed: () => filledSeed,
      setUp: () => stubResend(const Left(NoConnectionFailure())),
      act: (cubit) => cubit.resend(),
      expect: () => [
        isA<VerifyEmailState>().having(
          (s) => s.isResending,
          'isResending',
          isTrue,
        ),
        isA<VerifyEmailState>()
            .having((s) => s.isResending, 'isResending', isFalse)
            .having((s) => s.status, 'status', VerifyEmailStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<NoConnectionFailure>(),
            )
            .having((s) => s.code.value, 'code', '123456')
            .having((s) => s.resendCooldown, 'resendCooldown', 0),
      ],
    );
  });

  group('VerifyEmailCubit.codeChanged', () {
    blocTest<VerifyEmailCubit, VerifyEmailState>(
      'teclear tras authError limpia authFailure (casillas sin rojo) y '
      'devuelve status a initial',
      build: buildCubit,
      seed: () => const VerifyEmailState(
        email: email,
        code: CodeInput.dirty('123456'),
        status: VerifyEmailStatus.authError,
        authFailure: InvalidCodeFailure(),
      ),
      act: (cubit) => cubit.codeChanged('9'),
      expect: () => [
        isA<VerifyEmailState>()
            .having((s) => s.code.value, 'code', '9')
            .having((s) => s.status, 'status', VerifyEmailStatus.initial)
            .having((s) => s.authFailure, 'authFailure', isNull),
      ],
    );
  });
}
