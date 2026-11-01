import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/auth/auth_session.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/check_reset_code_use_case.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/forgot_password_use_case.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/reset_password_use_case.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/forgot_password_cubit.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/forgot_password_state.dart';
import 'package:depredadog_app/features/auth/presentation/inputs/code_input.dart';
import 'package:depredadog_app/features/auth/presentation/inputs/login_inputs.dart';
import 'package:depredadog_app/features/auth/presentation/inputs/register_inputs.dart';

class MockForgotPasswordUseCase extends Mock implements ForgotPasswordUseCase {}

class MockCheckResetCodeUseCase extends Mock implements CheckResetCodeUseCase {}

class MockResetPasswordUseCase extends Mock implements ResetPasswordUseCase {}

void main() {
  // Integración §012: los submits pegan a los use cases (mockeados,
  // patrón §010). AuthSession real: es solo el flag en memoria que el
  // éxito del reset marca para abrir /home.
  late MockForgotPasswordUseCase forgotUseCase;
  late MockCheckResetCodeUseCase checkUseCase;
  late MockResetPasswordUseCase resetUseCase;
  late AuthSession authSession;

  const user = User(
    id: 'u1',
    email: 'ana@ejemplo.com',
    firstName: 'Ana',
    firstLastName: 'Pérez',
    role: 'customer',
    status: 'active',
  );

  const validSeed = ForgotPasswordState(
    email: EmailInput.dirty('ana@ejemplo.com'),
    code: CodeInput.dirty('123456'),
    password: RegisterPasswordInput.dirty('secreto123'),
    confirmPassword: ConfirmPasswordInput.dirty(
      password: 'secreto123',
      value: 'secreto123',
    ),
    currentStep: ForgotPasswordState.lastStep,
  );

  setUp(() {
    forgotUseCase = MockForgotPasswordUseCase();
    checkUseCase = MockCheckResetCodeUseCase();
    resetUseCase = MockResetPasswordUseCase();
    authSession = AuthSession();
  });

  ForgotPasswordCubit buildCubit({AuthSession? session}) => ForgotPasswordCubit(
    forgotPasswordUseCase: forgotUseCase,
    checkResetCodeUseCase: checkUseCase,
    resetPasswordUseCase: resetUseCase,
    authSession: session ?? authSession,
  );

  void stubForgot(Either<AuthFailure, void> result) =>
      when(() => forgotUseCase(email: any(named: 'email')))
          .thenAnswer((_) async => result);

  void stubCheck(Either<AuthFailure, void> result) => when(
    () => checkUseCase(
      email: any(named: 'email'),
      code: any(named: 'code'),
    ),
  ).thenAnswer((_) async => result);

  void stubReset(Either<AuthFailure, User> result) => when(
    () => resetUseCase(
      email: any(named: 'email'),
      code: any(named: 'code'),
      newPassword: any(named: 'newPassword'),
    ),
  ).thenAnswer((_) async => result);

  group('ForgotPasswordCubit.nextStep', () {
    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'paso 0 vacío: failure con SOLO showEmailError → initial, no avanza',
      build: buildCubit,
      act: (cubit) => cubit.nextStep(),
      expect: () => [
        // El re-dirty del email vacío emite un primer estado igual al
        // inicial en todo menos… nada: pure→dirty SÍ cambia el input.
        isA<ForgotPasswordState>(),
        isA<ForgotPasswordState>()
            .having((s) => s.status, 'status', ForgotPasswordStatus.failure)
            .having((s) => s.showEmailError, 'email', true)
            // Los campos de los otros pasos no se tocan: validación por paso.
            .having((s) => s.showCodeError, 'code', false)
            .having((s) => s.showPasswordError, 'password', false)
            .having((s) => s.showConfirmPasswordError, 'confirm', false)
            .having((s) => s.currentStep, 'currentStep', 0),
        isA<ForgotPasswordState>().having(
          (s) => s.status,
          'status',
          ForgotPasswordStatus.initial,
        ),
      ],
      verify: (_) =>
          verifyNever(() => forgotUseCase(email: any(named: 'email'))),
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'paso 0 con email válido: forgotPassword OK → paso 1 con OTP limpio '
      '+ cooldown 60 corriendo (decisión §012)',
      build: buildCubit,
      seed: () => const ForgotPasswordState(
        email: EmailInput.dirty('ana@ejemplo.com'),
        // OTP/error viejos: cubre "cambié el correo y volví a pedir" —
        // el nuevo envío invalida lo anterior, todo se limpia.
        code: CodeInput.dirty('654321'),
        showCodeError: true,
      ),
      setUp: () => stubForgot(const Right(null)),
      act: (cubit) => cubit.nextStep(),
      expect: () => [
        isA<ForgotPasswordState>().having(
          (s) => s.status,
          'status',
          ForgotPasswordStatus.inProgress,
        ),
        isA<ForgotPasswordState>()
            .having((s) => s.currentStep, 'currentStep', 1)
            .having((s) => s.status, 'status', ForgotPasswordStatus.initial)
            .having((s) => s.code.value, 'code', '')
            .having((s) => s.showCodeError, 'showCodeError', false)
            .having((s) => s.resendCooldown, 'cooldown', 60),
      ],
      verify: (_) =>
          verify(() => forgotUseCase(email: 'ana@ejemplo.com')).called(1),
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'paso 0 con 429: inProgress → authError con TooManyAttemptsFailure '
      'sin mover de paso, correo intacto',
      build: buildCubit,
      seed: () =>
          const ForgotPasswordState(email: EmailInput.dirty('ana@ejemplo.com')),
      setUp: () => stubForgot(const Left(TooManyAttemptsFailure())),
      act: (cubit) => cubit.nextStep(),
      expect: () => [
        isA<ForgotPasswordState>().having(
          (s) => s.status,
          'status',
          ForgotPasswordStatus.inProgress,
        ),
        isA<ForgotPasswordState>()
            .having((s) => s.status, 'status', ForgotPasswordStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<TooManyAttemptsFailure>(),
            )
            .having((s) => s.currentStep, 'currentStep', 0)
            .having((s) => s.email.value, 'email', 'ana@ejemplo.com'),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'paso 0 sin red: inProgress → authError con NoConnectionFailure',
      build: buildCubit,
      seed: () =>
          const ForgotPasswordState(email: EmailInput.dirty('ana@ejemplo.com')),
      setUp: () => stubForgot(const Left(NoConnectionFailure())),
      act: (cubit) => cubit.nextStep(),
      expect: () => [
        isA<ForgotPasswordState>().having(
          (s) => s.status,
          'status',
          ForgotPasswordStatus.inProgress,
        ),
        isA<ForgotPasswordState>()
            .having((s) => s.status, 'status', ForgotPasswordStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<NoConnectionFailure>(),
            )
            .having((s) => s.currentStep, 'currentStep', 0),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'paso 1 con código incompleto: failure con SOLO showCodeError → '
      'initial, no avanza ni llama al check',
      build: buildCubit,
      seed: () => validSeed.copyWith(
        currentStep: 1,
        code: const CodeInput.dirty('123'),
      ),
      act: (cubit) => cubit.nextStep(),
      expect: () => [
        isA<ForgotPasswordState>()
            .having((s) => s.status, 'status', ForgotPasswordStatus.failure)
            .having((s) => s.showCodeError, 'code', true)
            .having((s) => s.showEmailError, 'email', false)
            .having((s) => s.showPasswordError, 'password', false)
            .having((s) => s.currentStep, 'currentStep', 1),
        isA<ForgotPasswordState>().having(
          (s) => s.status,
          'status',
          ForgotPasswordStatus.initial,
        ),
      ],
      verify: (_) => verifyNever(
        () => checkUseCase(
          email: any(named: 'email'),
          code: any(named: 'code'),
        ),
      ),
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'paso 1 con código válido: checkResetCode OK → paso 2 (nueva clave)',
      build: buildCubit,
      seed: () => validSeed.copyWith(currentStep: 1),
      setUp: () => stubCheck(const Right(null)),
      act: (cubit) => cubit.nextStep(),
      expect: () => [
        isA<ForgotPasswordState>().having(
          (s) => s.status,
          'status',
          ForgotPasswordStatus.inProgress,
        ),
        isA<ForgotPasswordState>()
            .having((s) => s.currentStep, 'currentStep', 2)
            .having((s) => s.status, 'status', ForgotPasswordStatus.initial),
      ],
      verify: (_) =>
          verify(() => checkUseCase(email: 'ana@ejemplo.com', code: '123456'))
              .called(1),
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'paso 1 con código rechazado (400): authError + InvalidCodeFailure '
      '— dígitos conservados en paso 2 (siguen vivos en el server)',
      build: buildCubit,
      seed: () => validSeed.copyWith(currentStep: 1),
      setUp: () => stubCheck(const Left(InvalidCodeFailure())),
      act: (cubit) => cubit.nextStep(),
      expect: () => [
        isA<ForgotPasswordState>().having(
          (s) => s.status,
          'status',
          ForgotPasswordStatus.inProgress,
        ),
        isA<ForgotPasswordState>()
            .having((s) => s.status, 'status', ForgotPasswordStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<InvalidCodeFailure>(),
            )
            .having((s) => s.currentStep, 'currentStep', 1)
            .having((s) => s.code.value, 'code', '123456'),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'paso 1 sin red: authError con NoConnectionFailure, dígitos '
      'conservados',
      build: buildCubit,
      seed: () => validSeed.copyWith(currentStep: 1),
      setUp: () => stubCheck(const Left(NoConnectionFailure())),
      act: (cubit) => cubit.nextStep(),
      expect: () => [
        isA<ForgotPasswordState>().having(
          (s) => s.status,
          'status',
          ForgotPasswordStatus.inProgress,
        ),
        isA<ForgotPasswordState>()
            .having((s) => s.status, 'status', ForgotPasswordStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<NoConnectionFailure>(),
            )
            .having((s) => s.currentStep, 'currentStep', 1)
            .having((s) => s.code.value, 'code', '123456'),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'paso 2 (nueva clave): no-op — su acción primaria es submit()',
      build: buildCubit,
      seed: () => validSeed,
      act: (cubit) => cubit.nextStep(),
      expect: () => <ForgotPasswordState>[],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'durante inProgress no re-emite (doble tap)',
      build: buildCubit,
      seed: () => validSeed.copyWith(status: ForgotPasswordStatus.inProgress),
      act: (cubit) => cubit.nextStep(),
      expect: () => <ForgotPasswordState>[],
      verify: (_) {
        verifyNever(() => forgotUseCase(email: any(named: 'email')));
        verifyNever(
          () => checkUseCase(
            email: any(named: 'email'),
            code: any(named: 'code'),
          ),
        );
      },
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'durante isResending no re-emite ("Verificar" esperaría el código '
      'que el reenvío invalida — carrera de verify-email)',
      build: buildCubit,
      seed: () => validSeed.copyWith(currentStep: 1, isResending: true),
      act: (cubit) => cubit.nextStep(),
      expect: () => <ForgotPasswordState>[],
      verify: (_) => verifyNever(
        () => checkUseCase(
          email: any(named: 'email'),
          code: any(named: 'code'),
        ),
      ),
    );
  });

  group('ForgotPasswordCubit.prevStep', () {
    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'retrocede un paso sin re-validar (los errores previos quedan)',
      build: buildCubit,
      seed: () => validSeed.copyWith(showCodeError: true),
      act: (cubit) => cubit.prevStep(),
      expect: () => [
        isA<ForgotPasswordState>()
            .having((s) => s.currentStep, 'currentStep', 1)
            // Sin re-validar: no toca flags ni inputs.
            .having((s) => s.showCodeError, 'showCodeError', true)
            .having((s) => s.email.value, 'email', 'ana@ejemplo.com'),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'en paso 0 no hace nada (clamp — ahí el back va a /login)',
      build: buildCubit,
      act: (cubit) => cubit.prevStep(),
      expect: () => <ForgotPasswordState>[],
    );
  });

  group('ForgotPasswordCubit.submit', () {
    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'inválido: failure con todas las banderas → initial '
      '(re-valida TODO aunque se dispare desde el paso 3)',
      build: buildCubit,
      seed: () => validSeed.copyWith(
        confirmPassword: const ConfirmPasswordInput.dirty(
          password: 'secreto123',
          value: 'otra12345',
        ),
      ),
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<ForgotPasswordState>()
            .having((s) => s.status, 'status', ForgotPasswordStatus.failure)
            .having((s) => s.showEmailError, 'email', true)
            .having((s) => s.showCodeError, 'code', true)
            .having((s) => s.showPasswordError, 'password', true)
            .having((s) => s.showConfirmPasswordError, 'confirmPassword', true),
        isA<ForgotPasswordState>().having(
          (s) => s.status,
          'status',
          ForgotPasswordStatus.initial,
        ),
      ],
      verify: (_) => verifyNever(
        () => resetUseCase(
          email: any(named: 'email'),
          code: any(named: 'code'),
          newPassword: any(named: 'newPassword'),
        ),
      ),
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'válido en paso 3: resetPassword OK → inProgress → success '
      '(auto-login — los tokens ya quedaron persistidos por el repo)',
      build: buildCubit,
      seed: () => validSeed,
      setUp: () => stubReset(const Right(user)),
      act: (cubit) => cubit.submit(),
      // El re-dirty del email produce un estado idéntico al seed (ya dirty
      // y trimmed) — bloc lo deduplica: solo se capturan inProgress y
      // success.
      expect: () => [
        isA<ForgotPasswordState>().having(
          (s) => s.status,
          'status',
          ForgotPasswordStatus.inProgress,
        ),
        isA<ForgotPasswordState>().having(
          (s) => s.status,
          'status',
          ForgotPasswordStatus.success,
        ),
      ],
      verify: (_) {
        verify(
          () => resetUseCase(
            email: 'ana@ejemplo.com',
            code: '123456',
            newPassword: 'secreto123',
          ),
        ).called(1);
      },
    );

    // Test plano (no blocTest): la aserción es sobre la AuthSession
    // inyectada, no sobre los estados emitidos.
    test('éxito marca la sesión con el usuario REAL — el stub '
        '"forgot-preview" quedó reemplazado por el auto-login '
        '(propuesta 012)', () async {
      stubReset(const Right(user));
      final session = AuthSession();
      final cubit = buildCubit(session: session);
      cubit.emit(validSeed);
      await cubit.submit();
      expect(session.isAuthenticated, isTrue);
      expect(session.currentUser, user);
      await cubit.close();
    });

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'InvalidCode (expiró entre check y submit — la carrera real): '
      'REBOTA al paso 2 con authError, dígitos conservados en rojo '
      '(decisión §012)',
      build: buildCubit,
      seed: () => validSeed,
      setUp: () => stubReset(const Left(InvalidCodeFailure())),
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<ForgotPasswordState>().having(
          (s) => s.status,
          'status',
          ForgotPasswordStatus.inProgress,
        ),
        isA<ForgotPasswordState>()
            .having((s) => s.currentStep, 'currentStep', 1)
            .having((s) => s.status, 'status', ForgotPasswordStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<InvalidCodeFailure>(),
            )
            .having((s) => s.code.value, 'code', '123456'),
      ],
      verify: (_) => expect(authSession.isAuthenticated, isFalse),
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      '429: authError en paso 3 — NO rebota, claves intactas',
      build: buildCubit,
      seed: () => validSeed,
      setUp: () => stubReset(const Left(TooManyAttemptsFailure())),
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<ForgotPasswordState>().having(
          (s) => s.status,
          'status',
          ForgotPasswordStatus.inProgress,
        ),
        isA<ForgotPasswordState>()
            .having((s) => s.status, 'status', ForgotPasswordStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<TooManyAttemptsFailure>(),
            )
            .having((s) => s.currentStep, 'currentStep', 2),
      ],
      verify: (_) => expect(authSession.isAuthenticated, isFalse),
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'sin red: authError con NoConnectionFailure en paso 3',
      build: buildCubit,
      seed: () => validSeed,
      setUp: () => stubReset(const Left(NoConnectionFailure())),
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<ForgotPasswordState>().having(
          (s) => s.status,
          'status',
          ForgotPasswordStatus.inProgress,
        ),
        isA<ForgotPasswordState>()
            .having((s) => s.status, 'status', ForgotPasswordStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<NoConnectionFailure>(),
            )
            .having((s) => s.currentStep, 'currentStep', 2),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'submit durante inProgress no re-emite '
      '(doble tap / done del teclado)',
      build: buildCubit,
      seed: () => validSeed.copyWith(status: ForgotPasswordStatus.inProgress),
      act: (cubit) => cubit.submit(),
      expect: () => <ForgotPasswordState>[],
      verify: (_) => verifyNever(
        () => resetUseCase(
          email: any(named: 'email'),
          code: any(named: 'code'),
          newPassword: any(named: 'newPassword'),
        ),
      ),
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'submit durante isResending no re-emite (paridad con verify)',
      build: buildCubit,
      seed: () => validSeed.copyWith(isResending: true),
      act: (cubit) => cubit.submit(),
      expect: () => <ForgotPasswordState>[],
    );
  });

  group('ForgotPasswordCubit.resend', () {
    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'reenvía con forgotPassword (no hay endpoint dedicado): '
      'isResending → código limpio + cooldown 60 + resendTick '
      '(el timer empieza a contar)',
      build: buildCubit,
      seed: () => validSeed.copyWith(
        currentStep: 1,
        code: const CodeInput.dirty('123456'),
        showCodeError: true,
      ),
      setUp: () => stubForgot(const Right(null)),
      act: (cubit) => cubit.resend(),
      expect: () => [
        isA<ForgotPasswordState>()
            .having((s) => s.isResending, 'isResending', true)
            .having((s) => s.status, 'status', ForgotPasswordStatus.initial),
        isA<ForgotPasswordState>()
            .having((s) => s.isResending, 'isResending', false)
            // El código quedó invalidado por el nuevo envío — se limpia
            // junto a su error (convención verify-email).
            .having((s) => s.code.value, 'code', '')
            .having((s) => s.showCodeError, 'showCodeError', false)
            .having((s) => s.resendCooldown, 'cooldown', 60)
            .having((s) => s.resendTick, 'tick', 1),
      ],
      verify: (_) =>
          verify(() => forgotUseCase(email: 'ana@ejemplo.com')).called(1),
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'el cooldown descuenta cada segundo tras el reenvío',
      build: buildCubit,
      seed: () => validSeed.copyWith(currentStep: 1),
      setUp: () => stubForgot(const Right(null)),
      act: (cubit) => cubit.resend(),
      // ~1.2s reales: alcanza el primer tick (59) sin tocar el segundo.
      wait: const Duration(milliseconds: 1200),
      expect: () => [
        isA<ForgotPasswordState>().having(
          (s) => s.isResending,
          'isResending',
          true,
        ),
        isA<ForgotPasswordState>().having(
          (s) => s.resendCooldown,
          'cooldown',
          60,
        ),
        isA<ForgotPasswordState>().having(
          (s) => s.resendCooldown,
          'cooldown',
          59,
        ),
      ],
    );

    // Regresión del copyWith por status EFECTIVO (revisor §012): con el
    // cooldown corriendo, un tick (copyWith sin status) no debe nullear
    // authFailure — si lo hiciera, las casillas rojas morirían en ≤1s.
    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'authError con cooldown corriendo: el tick preserva authFailure',
      build: buildCubit,
      seed: () => validSeed.copyWith(currentStep: 1),
      setUp: () {
        stubForgot(const Right(null));
        stubCheck(const Left(InvalidCodeFailure()));
      },
      act: (cubit) async {
        await cubit.resend(); // cooldown 60 + timer corriendo
        cubit.codeChanged('654321');
        await cubit.nextStep(); // check rechaza → authError
      },
      // ~1.2s reales: cruza un tick del timer tras el authError.
      wait: const Duration(milliseconds: 1200),
      expect: () => [
        isA<ForgotPasswordState>().having(
          (s) => s.isResending,
          'isResending',
          true,
        ),
        isA<ForgotPasswordState>().having(
          (s) => s.resendCooldown,
          'cooldown',
          60,
        ),
        isA<ForgotPasswordState>().having(
          (s) => s.code.value,
          'codeChanged',
          '654321',
        ),
        isA<ForgotPasswordState>().having(
          (s) => s.status,
          'status',
          ForgotPasswordStatus.inProgress,
        ),
        isA<ForgotPasswordState>()
            .having((s) => s.status, 'status', ForgotPasswordStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<InvalidCodeFailure>(),
            ),
        // El tick del cooldown descuenta PERO el authFailure sobrevive —
        // la regresión a fijar (copyWith evalúa el status efectivo).
        isA<ForgotPasswordState>()
            .having((s) => s.resendCooldown, 'cooldown', 59)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<InvalidCodeFailure>(),
            ),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'reenvío fallido (429): authError y el código tipeado se conserva '
      '(sigue vivo en el server — convención verify), sin cooldown',
      build: buildCubit,
      seed: () => validSeed.copyWith(
        currentStep: 1,
        code: const CodeInput.dirty('123456'),
      ),
      setUp: () => stubForgot(const Left(TooManyAttemptsFailure())),
      act: (cubit) => cubit.resend(),
      expect: () => [
        isA<ForgotPasswordState>()
            .having((s) => s.isResending, 'isResending', true)
            .having((s) => s.status, 'status', ForgotPasswordStatus.initial),
        isA<ForgotPasswordState>()
            .having((s) => s.isResending, 'isResending', false)
            .having((s) => s.status, 'status', ForgotPasswordStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<TooManyAttemptsFailure>(),
            )
            .having((s) => s.code.value, 'code', '123456')
            .having((s) => s.resendCooldown, 'cooldown', 0)
            .having((s) => s.resendTick, 'tick', 0),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'durante el cooldown no re-emite (canResend = false)',
      build: buildCubit,
      seed: () => validSeed.copyWith(currentStep: 1, resendCooldown: 42),
      act: (cubit) => cubit.resend(),
      expect: () => <ForgotPasswordState>[],
      verify: (_) =>
          verifyNever(() => forgotUseCase(email: any(named: 'email'))),
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'durante isResending no re-emite (doble tap)',
      build: buildCubit,
      seed: () => validSeed.copyWith(currentStep: 1, isResending: true),
      act: (cubit) => cubit.resend(),
      expect: () => <ForgotPasswordState>[],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'durante inProgress no re-emite (invalidaría el código del submit '
      'en vuelo)',
      build: buildCubit,
      seed: () => validSeed.copyWith(
        currentStep: 1,
        status: ForgotPasswordStatus.inProgress,
      ),
      act: (cubit) => cubit.resend(),
      expect: () => <ForgotPasswordState>[],
    );
  });

  group('ForgotPasswordCubit.*Changed', () {
    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'emailChanged hace dirty trimmeado, limpia showEmailError y '
      're-arma el listener (status → initial)',
      build: buildCubit,
      seed: () => const ForgotPasswordState(
        email: EmailInput.dirty('viejo@ejemplo.com'),
        status: ForgotPasswordStatus.failure,
        showEmailError: true,
      ),
      act: (cubit) => cubit.emailChanged('  nuevo@ejemplo.com  '),
      expect: () => [
        isA<ForgotPasswordState>()
            .having((s) => s.email.value, 'email', 'nuevo@ejemplo.com')
            .having((s) => s.showEmailError, 'showEmailError', false)
            .having((s) => s.status, 'status', ForgotPasswordStatus.initial)
            .having((s) => s.emailErrorKey(), 'emailErrorKey', isNull),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'codeChanged hace dirty y limpia showCodeError',
      build: buildCubit,
      seed: () =>
          const ForgotPasswordState(currentStep: 1, showCodeError: true),
      act: (cubit) => cubit.codeChanged('1234'),
      expect: () => [
        isA<ForgotPasswordState>()
            .having((s) => s.code.value, 'code', '1234')
            .having((s) => s.showCodeError, 'showCodeError', false)
            .having((s) => s.status, 'status', ForgotPasswordStatus.initial),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'codeChanged tras authError limpia authFailure (las casillas dejan '
      'de pintarse en rojo) — patrón verify-email',
      build: buildCubit,
      seed: () => validSeed.copyWith(
        currentStep: 1,
        status: ForgotPasswordStatus.authError,
        authFailure: const InvalidCodeFailure(),
      ),
      act: (cubit) => cubit.codeChanged('9'),
      expect: () => [
        isA<ForgotPasswordState>()
            .having((s) => s.code.value, 'code', '9')
            .having((s) => s.status, 'status', ForgotPasswordStatus.initial)
            .having((s) => s.authFailure, 'authFailure', isNull),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'codeChanged durante isResending NO emite — el éxito del reenvío '
      'borraría lo tipeado (guard extra vs verify, que solo bloquea puntero)',
      build: buildCubit,
      seed: () => validSeed.copyWith(currentStep: 1, isResending: true),
      act: (cubit) => cubit.codeChanged('1234'),
      expect: () => <ForgotPasswordState>[],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'passwordChanged re-emite la confirmación con la referencia nueva '
      '(un match previo pasa a mismatch al instante)',
      build: buildCubit,
      seed: () => validSeed,
      act: (cubit) => cubit.passwordChanged('nueva12345'),
      expect: () => [
        isA<ForgotPasswordState>()
            .having((s) => s.password.value, 'password', 'nueva12345')
            .having(
              (s) => s.confirmPassword.password,
              'confirm ref',
              'nueva12345',
            )
            // El valor viejo 'secreto123' ya no coincide con la nueva.
            .having(
              (s) => s.confirmPassword.isNotValid,
              'confirm inválida',
              true,
            ),
      ],
    );

    blocTest<ForgotPasswordCubit, ForgotPasswordState>(
      'emailChanged durante inProgress no emite — una edición en pleno '
      'submit apagaría el spinner antes de tiempo (guard revisor-ui)',
      build: buildCubit,
      seed: () => validSeed.copyWith(status: ForgotPasswordStatus.inProgress),
      act: (cubit) => cubit.emailChanged('otro@ejemplo.com'),
      expect: () => <ForgotPasswordState>[],
    );
  });

  group('inputs del wizard (reglas unitarias)', () {
    test('CodeInput: exactamente 6 dígitos numéricos', () {
      expect(const CodeInput.dirty().error, CodeValidationError.empty);
      expect(const CodeInput.dirty('123456').isValid, isTrue);
      // Largos distintos de 6 y no-numéricos: inválidos.
      for (final bad in ['12345', '1234567', 'abcdef', '12345a', '      ']) {
        expect(
          CodeInput.dirty(bad).error,
          CodeValidationError.invalid,
          reason: bad,
        );
      }
    });
  });
}
