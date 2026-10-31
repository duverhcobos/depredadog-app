import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/register_use_case.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/register_cubit.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/register_state.dart';
import 'package:depredadog_app/features/auth/presentation/inputs/login_inputs.dart';
import 'package:depredadog_app/features/auth/presentation/inputs/register_inputs.dart';

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

void main() {
  late MockRegisterUseCase useCase;

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

  const validSeed = RegisterState(
    firstName: NameInput.dirty('Ana'),
    secondName: OptionalTextInput.dirty('María'),
    firstLastName: NameInput.dirty('Pérez'),
    secondLastName: OptionalTextInput.dirty('Gómez'),
    email: EmailInput.dirty('ana@ejemplo.com'),
    phone: PhoneInput.dirty('3001234567'),
    password: RegisterPasswordInput.dirty('secreto123'),
    confirmPassword: ConfirmPasswordInput.dirty(
      password: 'secreto123',
      value: 'secreto123',
    ),
    currentStep: RegisterState.lastStep,
  );

  setUp(() {
    useCase = MockRegisterUseCase();
  });

  RegisterCubit buildCubit() => RegisterCubit(registerUseCase: useCase);

  void stubRegister(Either<AuthFailure, User> result) => when(
    () => useCase(
      email: any(named: 'email'),
      password: any(named: 'password'),
      firstName: any(named: 'firstName'),
      secondName: any(named: 'secondName'),
      firstLastName: any(named: 'firstLastName'),
      secondLastName: any(named: 'secondLastName'),
      phone: any(named: 'phone'),
    ),
  ).thenAnswer((_) async => result);

  void verifyNeverRegister() => verifyNever(
    () => useCase(
      email: any(named: 'email'),
      password: any(named: 'password'),
      firstName: any(named: 'firstName'),
      secondName: any(named: 'secondName'),
      firstLastName: any(named: 'firstLastName'),
      secondLastName: any(named: 'secondLastName'),
      phone: any(named: 'phone'),
    ),
  );

  group('RegisterCubit.nextStep', () {
    blocTest<RegisterCubit, RegisterState>(
      'paso 0 vacío: failure con SOLO las banderas del paso → initial, '
      'no avanza',
      build: buildCubit,
      act: (cubit) => cubit.nextStep(),
      expect: () => [
        isA<RegisterState>()
            .having((s) => s.status, 'status', RegisterStatus.failure)
            .having((s) => s.showFirstNameError, 'firstName', true)
            .having((s) => s.showFirstLastNameError, 'firstLastName', true)
            .having((s) => s.showPhoneError, 'phone', true)
            // Los campos de paso 2 no se tocan: validación por paso.
            .having((s) => s.showEmailError, 'email', false)
            .having((s) => s.showPasswordError, 'password', false)
            .having((s) => s.showConfirmPasswordError, 'confirm', false)
            .having((s) => s.currentStep, 'currentStep', 0),
        isA<RegisterState>().having(
          (s) => s.status,
          'status',
          RegisterStatus.initial,
        ),
      ],
    );

    blocTest<RegisterCubit, RegisterState>(
      'paso 0 válido: avanza a paso 1 aunque la cuenta siga vacía',
      build: buildCubit,
      // Solo los campos del paso 1 diligenciados — prueba que la
      // validación es por paso (email/password vacíos no bloquean).
      seed: () => const RegisterState(
        firstName: NameInput.dirty('Ana'),
        firstLastName: NameInput.dirty('Pérez'),
      ),
      act: (cubit) => cubit.nextStep(),
      expect: () => [
        isA<RegisterState>()
            .having((s) => s.currentStep, 'currentStep', 1)
            .having((s) => s.status, 'status', RegisterStatus.initial),
      ],
    );

    blocTest<RegisterCubit, RegisterState>(
      'paso 1 inválido: failure con SOLO banderas de cuenta → initial, '
      'no avanza',
      build: buildCubit,
      seed: () => validSeed.copyWith(
        currentStep: 1,
        email: const EmailInput.dirty('malo'),
      ),
      act: (cubit) => cubit.nextStep(),
      expect: () => [
        isA<RegisterState>()
            .having((s) => s.status, 'status', RegisterStatus.failure)
            .having((s) => s.showEmailError, 'email', true)
            .having((s) => s.showPasswordError, 'password', true)
            .having((s) => s.showConfirmPasswordError, 'confirm', true)
            // Los campos del paso 1 no se tocan.
            .having((s) => s.showFirstNameError, 'firstName', false)
            .having((s) => s.showFirstLastNameError, 'firstLastName', false)
            .having((s) => s.showPhoneError, 'phone', false)
            .having((s) => s.currentStep, 'currentStep', 1),
        isA<RegisterState>().having(
          (s) => s.status,
          'status',
          RegisterStatus.initial,
        ),
      ],
    );

    blocTest<RegisterCubit, RegisterState>(
      'paso 1 válido: avanza a paso 2 (revisión)',
      build: buildCubit,
      seed: () => validSeed.copyWith(currentStep: 1),
      act: (cubit) => cubit.nextStep(),
      // El re-dirty del email produce un estado idéntico al seed (ya dirty
      // y trimmed) — bloc lo deduplica: solo se captura el avance.
      expect: () => [
        isA<RegisterState>()
            .having((s) => s.currentStep, 'currentStep', 2)
            .having((s) => s.status, 'status', RegisterStatus.initial),
      ],
    );

    blocTest<RegisterCubit, RegisterState>(
      'paso 2 (revisión): no-op — su acción primaria es submit()',
      build: buildCubit,
      seed: () => validSeed,
      act: (cubit) => cubit.nextStep(),
      expect: () => <RegisterState>[],
    );

    blocTest<RegisterCubit, RegisterState>(
      'durante inProgress no re-emite (doble tap)',
      build: buildCubit,
      seed: () => validSeed.copyWith(status: RegisterStatus.inProgress),
      act: (cubit) => cubit.nextStep(),
      expect: () => <RegisterState>[],
    );
  });

  group('RegisterCubit.prevStep', () {
    blocTest<RegisterCubit, RegisterState>(
      'retrocede un paso sin re-validar (los errores previos quedan)',
      build: buildCubit,
      seed: () => validSeed.copyWith(showEmailError: true),
      act: (cubit) => cubit.prevStep(),
      expect: () => [
        isA<RegisterState>()
            .having((s) => s.currentStep, 'currentStep', 1)
            // Sin re-validar: no toca flags ni inputs.
            .having((s) => s.showEmailError, 'showEmailError', true)
            .having((s) => s.firstName.value, 'firstName', 'Ana'),
      ],
    );

    blocTest<RegisterCubit, RegisterState>(
      'en paso 0 no hace nada (clamp — la flecha de paso 1 va a /login)',
      build: buildCubit,
      act: (cubit) => cubit.prevStep(),
      expect: () => <RegisterState>[],
    );
  });

  group('RegisterCubit.submit', () {
    blocTest<RegisterCubit, RegisterState>(
      'inválido: failure con todas las banderas → initial '
      '(re-valida TODO aunque se dispare desde la revisión) '
      'y NO llama al use case',
      build: buildCubit,
      seed: () => validSeed.copyWith(
        confirmPassword: const ConfirmPasswordInput.dirty(
          password: 'secreto123',
          value: 'otra12345',
        ),
      ),
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<RegisterState>()
            .having((s) => s.status, 'status', RegisterStatus.failure)
            .having((s) => s.showFirstNameError, 'firstName', true)
            .having((s) => s.showEmailError, 'email', true)
            .having((s) => s.showConfirmPasswordError, 'confirmPassword', true),
        isA<RegisterState>().having(
          (s) => s.status,
          'status',
          RegisterStatus.initial,
        ),
      ],
      verify: (_) => verifyNeverRegister(),
    );

    blocTest<RegisterCubit, RegisterState>(
      'válido en paso 3: inProgress → success, use case recibe los campos '
      'de los 3 pasos (requeridos trimmed)',
      build: buildCubit,
      seed: () => validSeed,
      setUp: () => stubRegister(const Right(user)),
      act: (cubit) => cubit.submit(),
      // El re-dirty del email produce un estado idéntico al seed (ya dirty
      // y trimmed) — bloc lo deduplica por == y no notifica: solo se
      // capturan inProgress y success.
      expect: () => [
        isA<RegisterState>().having(
          (s) => s.status,
          'status',
          RegisterStatus.inProgress,
        ),
        isA<RegisterState>().having(
          (s) => s.status,
          'status',
          RegisterStatus.success,
        ),
      ],
      verify: (_) => verify(
        () => useCase(
          email: 'ana@ejemplo.com',
          password: 'secreto123',
          firstName: 'Ana',
          secondName: 'María',
          firstLastName: 'Pérez',
          secondLastName: 'Gómez',
          phone: '3001234567',
        ),
      ).called(1),
    );

    blocTest<RegisterCubit, RegisterState>(
      'opcionales vacíos llegan al use case como null (el datasource '
      'omite la clave en el body)',
      build: buildCubit,
      // Sin segundo nombre/apellido ni teléfono — los OptionalTextInput/
      // PhoneInput quedan pure (valor '').
      seed: () => const RegisterState(
        firstName: NameInput.dirty('  Ana  '),
        firstLastName: NameInput.dirty(' Pérez '),
        email: EmailInput.dirty('ana@ejemplo.com'),
        password: RegisterPasswordInput.dirty('secreto123'),
        confirmPassword: ConfirmPasswordInput.dirty(
          password: 'secreto123',
          value: 'secreto123',
        ),
        currentStep: RegisterState.lastStep,
      ),
      setUp: () => stubRegister(const Right(user)),
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<RegisterState>().having(
          (s) => s.status,
          'status',
          RegisterStatus.inProgress,
        ),
        isA<RegisterState>().having(
          (s) => s.status,
          'status',
          RegisterStatus.success,
        ),
      ],
      verify: (_) => verify(
        () => useCase(
          email: 'ana@ejemplo.com',
          password: 'secreto123',
          // Los requeridos también van trimmeados (backend: Matches(/\S/)).
          firstName: 'Ana',
          secondName: null,
          firstLastName: 'Pérez',
          secondLastName: null,
          phone: null,
        ),
      ).called(1),
    );

    blocTest<RegisterCubit, RegisterState>(
      '409 correo duplicado: authError volviendo al paso 2 con el correo '
      'marcado (emailTaken) → initial conserva el campo en rojo',
      build: buildCubit,
      seed: () => validSeed,
      setUp: () => stubRegister(const Left(EmailAlreadyRegisteredFailure())),
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<RegisterState>().having(
          (s) => s.status,
          'status',
          RegisterStatus.inProgress,
        ),
        isA<RegisterState>()
            .having((s) => s.status, 'status', RegisterStatus.authError)
            .having(
              (s) => s.authFailure,
              'authFailure',
              isA<EmailAlreadyRegisteredFailure>(),
            )
            .having((s) => s.currentStep, 'currentStep', 1)
            .having((s) => s.showEmailError, 'showEmailError', true)
            .having((s) => s.emailTaken, 'emailTaken', true)
            .having((s) => s.emailErrorKey(), 'emailErrorKey', 'taken'),
        isA<RegisterState>()
            .having((s) => s.status, 'status', RegisterStatus.initial)
            .having((s) => s.authFailure, 'authFailure', isNull)
            // emailTaken/showEmailError sobreviven al re-armado: el correo
            // queda rojo hasta que el usuario lo edite.
            .having((s) => s.currentStep, 'currentStep', 1)
            .having((s) => s.emailTaken, 'emailTaken', true)
            .having((s) => s.emailErrorKey(), 'emailErrorKey', 'taken'),
      ],
    );

    // Errores sin campo que señalar: authError + toast, sin moverse de
    // paso (el usuario sigue en la revisión).
    for (final (name, failure) in [
      ('429 throttle', const TooManyAttemptsFailure()),
      ('sin conexión', const NoConnectionFailure()),
      ('500 ajeno', const UnknownAuthFailure('Boom')),
    ]) {
      blocTest<RegisterCubit, RegisterState>(
        '$name: authError → initial SIN cambiar de paso ni marcar campos',
        build: buildCubit,
        seed: () => validSeed,
        setUp: () => stubRegister(Left(failure)),
        act: (cubit) => cubit.submit(),
        expect: () => [
          isA<RegisterState>().having(
            (s) => s.status,
            'status',
            RegisterStatus.inProgress,
          ),
          isA<RegisterState>()
              .having((s) => s.status, 'status', RegisterStatus.authError)
              .having((s) => s.authFailure, 'authFailure', failure)
              .having((s) => s.currentStep, 'currentStep', 2)
              .having((s) => s.emailTaken, 'emailTaken', false)
              .having((s) => s.showEmailError, 'showEmailError', false),
          isA<RegisterState>()
              .having((s) => s.status, 'status', RegisterStatus.initial)
              .having((s) => s.authFailure, 'authFailure', isNull),
        ],
      );
    }

    blocTest<RegisterCubit, RegisterState>(
      'submit durante inProgress no re-emite ni re-llama '
      '(doble tap / done del teclado)',
      build: buildCubit,
      seed: () => validSeed.copyWith(status: RegisterStatus.inProgress),
      act: (cubit) => cubit.submit(),
      expect: () => <RegisterState>[],
      verify: (_) => verifyNeverRegister(),
    );
  });

  group('RegisterCubit.*Changed', () {
    blocTest<RegisterCubit, RegisterState>(
      'emailChanged limpia showEmailError + emailTaken + authFailure '
      'y vuelve a initial',
      build: buildCubit,
      seed: () => const RegisterState(
        email: EmailInput.dirty('tomado@ejemplo.com'),
        status: RegisterStatus.authError,
        showEmailError: true,
        emailTaken: true,
        authFailure: EmailAlreadyRegisteredFailure(),
      ),
      act: (cubit) => cubit.emailChanged('nuevo@ejemplo.com'),
      expect: () => [
        isA<RegisterState>()
            .having((s) => s.email.value, 'email', 'nuevo@ejemplo.com')
            .having((s) => s.showEmailError, 'showEmailError', false)
            .having((s) => s.emailTaken, 'emailTaken', false)
            .having((s) => s.status, 'status', RegisterStatus.initial)
            .having((s) => s.authFailure, 'authFailure', isNull)
            .having((s) => s.emailErrorKey(), 'emailErrorKey', isNull),
      ],
    );

    blocTest<RegisterCubit, RegisterState>(
      'passwordChanged re-emite la confirmación con la referencia nueva '
      '(un match previo pasa a mismatch al instante)',
      build: buildCubit,
      seed: () => validSeed,
      act: (cubit) => cubit.passwordChanged('nueva12345'),
      expect: () => [
        isA<RegisterState>()
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
  });

  group('inputs del registro (reglas unitarias)', () {
    test('NameInput: vacío o solo espacios es inválido', () {
      expect(const NameInput.dirty().isNotValid, isTrue);
      expect(const NameInput.dirty('   ').isNotValid, isTrue);
      expect(const NameInput.dirty('Ana').isValid, isTrue);
    });

    test('NameInput: solo letras latinas, espacio y apóstrofe (sin guion)', () {
      // Válidos: simples, con tilde/ñ y compuestos latinos.
      for (final ok in [
        'Ana',
        'Pérez',
        'María José',
        'De la Cruz',
        'O\u2019Neil',
        "O'Neil",
        'Núñez',
      ]) {
        expect(NameInput.dirty(ok).isValid, isTrue, reason: ok);
      }
      // Inválidos: dígitos, correos, guion, símbolos, solo separadores.
      for (final bad in [
        'Ana123',
        'duver@sadfsd.dgsdfg',
        'García-Márquez',
        'Juan_Carlos',
        "'''",
        'Nombre#1',
      ]) {
        expect(
          NameInput.dirty(bad).error,
          NameValidationError.invalid,
          reason: bad,
        );
      }
    });

    test('OptionalTextInput: siempre válido aunque esté vacío', () {
      expect(const OptionalTextInput.pure().isValid, isTrue);
      expect(const OptionalTextInput.dirty().isValid, isTrue);
    });

    test('PhoneInput: vacío válido; solo celular colombiano 3XX XXX XXXX', () {
      expect(const PhoneInput.dirty().isValid, isTrue);
      expect(const PhoneInput.dirty('3001234567').isValid, isTrue);
      expect(const PhoneInput.dirty('3509998887').isValid, isTrue);
      // Letras, prefijos no-3, largos distintos de 10 y fijos: inválidos.
      for (final bad in [
        'abcdefg',
        '+573001234567',
        '2001234567',
        '300123456',
        '30012345678',
        '6011234567',
      ]) {
        expect(
          PhoneInput.dirty(bad).error,
          PhoneValidationError.invalid,
          reason: bad,
        );
      }
    });

    test('RegisterPasswordInput: exige 8 caracteres (no 6 como login)', () {
      expect(
        const RegisterPasswordInput.dirty('1234567').error,
        RegisterPasswordValidationError.tooShort,
      );
      expect(const RegisterPasswordInput.dirty('12345678').isValid, isTrue);
    });

    test('ConfirmPasswordInput: empty y mismatch', () {
      expect(
        const ConfirmPasswordInput.dirty(password: 'abc12345').error,
        ConfirmPasswordValidationError.empty,
      );
      expect(
        const ConfirmPasswordInput.dirty(
          password: 'abc12345',
          value: 'xyz',
        ).error,
        ConfirmPasswordValidationError.mismatch,
      );
      expect(
        const ConfirmPasswordInput.dirty(
          password: 'abc12345',
          value: 'abc12345',
        ).isValid,
        isTrue,
      );
    });
  });
}
