import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/core/auth/auth_session.dart';
import 'package:depredadog_app/core/di/setup_di.dart';
import 'package:depredadog_app/core/routes/auth_guard.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/check_reset_code_use_case.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/forgot_password_use_case.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/reset_password_use_case.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/forgot_password_cubit.dart';
import 'package:depredadog_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

class MockForgotPasswordUseCase extends Mock implements ForgotPasswordUseCase {}

class MockCheckResetCodeUseCase extends Mock implements CheckResetCodeUseCase {}

class MockResetPasswordUseCase extends Mock implements ResetPasswordUseCase {}

void main() {
  // Integración §012: la pantalla resuelve su cubit por locator — los 3
  // use cases van mockeados (defaults benignos: todo responde éxito; un
  // llamado no stubeado de mocktail explotaría el pump). AuthSession
  // real: el éxito del reset la marca (auto-login → /home).
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

  setUp(() {
    forgotUseCase = MockForgotPasswordUseCase();
    checkUseCase = MockCheckResetCodeUseCase();
    resetUseCase = MockResetPasswordUseCase();
    authSession = AuthSession();
    when(() => forgotUseCase(email: any(named: 'email')))
        .thenAnswer((_) async => const Right<AuthFailure, void>(null));
    when(
      () => checkUseCase(
        email: any(named: 'email'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) async => const Right<AuthFailure, void>(null));
    when(
      () => resetUseCase(
        email: any(named: 'email'),
        code: any(named: 'code'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async => const Right<AuthFailure, User>(user));
    locator.registerLazySingleton<AuthSession>(() => authSession);
    locator.registerFactory<ForgotPasswordCubit>(
      () => ForgotPasswordCubit(
        forgotPasswordUseCase: forgotUseCase,
        checkResetCodeUseCase: checkUseCase,
        resetPasswordUseCase: resetUseCase,
        authSession: authSession,
      ),
    );
  });

  tearDown(() => locator.reset());

  /// Al entrar al paso 2 arranca el cooldown (Timer.periodic — nunca deja
  /// "settled" el árbol, pumpAndSettle colgaría): desmontar la vista cierra
  /// el cubit y cancela el timer para no dejarlo pendiente al terminar.
  Future<void> unmountForgot(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  /// Color de error del tema para asertar las casillas OTP en rojo.
  Color errorColor() => AppTheme.dark().colorScheme.error;

  /// Borde superior de la casilla i del OTP (AnimatedContainer del
  /// SixDigitCodeField).
  Color cellBorderColor(WidgetTester tester, int i) {
    final cell = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).at(i),
    );
    final box = cell.decoration! as BoxDecoration;
    return box.border!.top.color;
  }

  Future<void> pumpForgot(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: const ForgotPasswordScreen(),
      ),
    );
  }

  /// Pump que sustituye a pumpAndSettle cuando puede haber transición de
  /// paso: al entrar al paso 2 el cooldown (Timer.periodic) impide que el
  /// árbol "settle". 3 frames de 300ms cubren la secuencia completa:
  /// (1) el emit del cubit instala el nuevo child del AnimatedSwitcher,
  /// (2) corre la transición (~250ms), (3) el child saliente se retira —
  /// sin esto, finders como TextField/"Atrás" ven doble.
  Future<void> pumpStepTransition(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Tap del botón primario del paso visible (queda dentro del scroll).
  Future<void> tapPrimary(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pump();
    await tester.tap(find.text(label));
    await pumpStepTransition(tester);
  }

  /// Tap del "Atrás" secundario (TextButton, dentro del scroll igual
  /// que el primario). Mismo motivo para no usar pumpAndSettle.
  Future<void> tapBackStep(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Atrás'));
    await tester.pump();
    await tester.tap(find.text('Atrás'));
    await pumpStepTransition(tester);
  }

  /// ForgotPasswordScreen con un GoRouter real: los tests que verifican
  /// navegación (flecha → /login, submit → /home, back nativo) necesitan
  /// las rutas destino registradas (patrón register_screen_test).
  /// Si [pushForgot] es true se llega a la ruta con push() — el back
  /// nativo/flecha la POPEA conservando el stack (entrada real desde el
  /// link del login); si es false arranca directo (deep link) y la
  /// salida cae al fallback go(/login).
  Future<GoRouter> pumpForgotWithRouter(
    WidgetTester tester, {
    bool pushForgot = false,
  }) async {
    final router = GoRouter(
      initialLocation: AuthGuard.loginRoute,
      routes: [
        GoRoute(
          path: AuthGuard.loginRoute,
          builder: (context, state) =>
              const Scaffold(body: Text('PANTALLA LOGIN')),
        ),
        GoRoute(
          path: AuthGuard.forgotPasswordRoute,
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: AuthGuard.homeRoute,
          builder: (context, state) =>
              const Scaffold(body: Text('PANTALLA HOME')),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.dark(),
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
      ),
    );
    await tester.pumpAndSettle();
    if (pushForgot) {
      router.push(AuthGuard.forgotPasswordRoute);
      await tester.pumpAndSettle();
    } else {
      router.go(AuthGuard.forgotPasswordRoute);
      await tester.pumpAndSettle();
    }
    return router;
  }

  /// Diligencia el paso 1 (correo) y avanza al paso 2 — el envío real
  /// arranca el cooldown de reenvío (decisión §012).
  Future<void> goToStep2(
    WidgetTester tester, {
    String email = 'ana@ejemplo.com',
  }) async {
    await tester.enterText(find.byKey(const ValueKey('forgot_email')), email);
    await tapPrimary(tester, 'Enviar código');
  }

  /// Diligencia el paso 2 (código completo) — el auto-submit del 6to
  /// dígito ya hace el check real y avanza al paso 3.
  Future<void> goToStep3(WidgetTester tester) async {
    await goToStep2(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await pumpStepTransition(tester);
  }

  /// Diligencia el paso 3 (nueva clave + confirmación).
  Future<void> fillStep3(
    WidgetTester tester, {
    String password = 'secreto123',
    String? confirm,
  }) async {
    await tester.enterText(
      find.byKey(const ValueKey('forgot_password')),
      password,
    );
    await tester.enterText(
      find.byKey(const ValueKey('forgot_confirm_password')),
      confirm ?? password,
    );
  }

  testWidgets('paso 1: stepper, correo y acciones persistentes '
      '(sin imagotipo)', (tester) async {
    await pumpForgot(tester);
    await tester.pump();

    // Stepper visual con sus 3 labels.
    expect(find.text('Correo'), findsOneWidget);
    expect(find.text('Código'), findsOneWidget);
    expect(find.text('Clave'), findsOneWidget);
    // Título/subtítulo del paso 1 — sin imagotipo.
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(
      find.text('Te enviamos un código para restablecerla.'),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);
    // Solo el campo de correo.
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Correo electrónico *'), findsOneWidget);
    // Acciones persistentes.
    expect(find.text('Enviar código'), findsOneWidget);
    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    // En paso 1 no hay "Atrás" (primario a todo el ancho).
    expect(find.text('Atrás'), findsNothing);
  });

  testWidgets('flecha de volver y stepper quedan fijos arriba, fuera '
      'del scroll', (tester) async {
    await pumpForgot(tester);
    await tester.pump();

    final arrowTopLeft = tester.getTopLeft(find.byIcon(Icons.arrow_back));
    expect(arrowTopLeft.dy, lessThan(80));
    final stepperTopLeft = tester.getTopLeft(find.text('Correo'));
    expect(stepperTopLeft.dy, lessThan(160));
  });

  testWidgets('enviar código con correo vacío: error solo en su campo', (
    tester,
  ) async {
    await pumpForgot(tester);
    await tester.pump();

    await tapPrimary(tester, 'Enviar código');

    expect(find.text('Ingresa tu correo'), findsOneWidget);
    // Sigue en el paso 1.
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    verifyNever(() => forgotUseCase(email: any(named: 'email')));
  });

  testWidgets('enviar código con correo mal formado: "Correo incorrecto"', (
    tester,
  ) async {
    await pumpForgot(tester);
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('forgot_email')),
      'no-es-correo',
    );
    await tapPrimary(tester, 'Enviar código');

    expect(find.text('Correo incorrecto'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    verifyNever(() => forgotUseCase(email: any(named: 'email')));
  });

  testWidgets('paso 2: OTP de 6 casillas + email en el subtítulo + '
      'cooldown 60s ya corriendo (decisión §012)', (tester) async {
    await pumpForgot(tester);
    await tester.pump();

    await goToStep2(tester);

    expect(find.text('Revisa tu correo'), findsOneWidget);
    // El correo del paso 1 viaja al subtítulo.
    expect(
      find.text('Enviamos un código de 6 dígitos a ana@ejemplo.com'),
      findsOneWidget,
    );
    // 6 casillas + el TextField invisible que captura el teclado.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNWidgets(6));
    expect(find.text('Verificar'), findsOneWidget);
    // El código acaba de salir: el reenvío arranca en cooldown — un
    // reenvío inmediato solo quemaría el throttle (3 req/min).
    expect(find.text('Reenviar en 60s'), findsOneWidget);
    expect(find.text('Reenviar'), findsNothing);
    expect(find.text('Atrás'), findsOneWidget);
    // El teclado NO se abre solo al entrar al paso: el campo oculto no
    // tiene foco (autofocus:false — distinto de verify-email).
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isNot(true),
    );

    await unmountForgot(tester);
  });

  testWidgets('verificar con código incompleto no avanza del paso 2', (
    tester,
  ) async {
    await pumpForgot(tester);
    await tester.pump();

    await goToStep2(tester);
    await tester.enterText(find.byType(TextField), '123');
    await tester.pump(const Duration(milliseconds: 50));
    await tapPrimary(tester, 'Verificar');

    // Sigue en el paso 2 (la validación es por paso) — sin llamar al check.
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.text('Crea tu nueva contraseña'), findsNothing);
    verifyNever(
      () => checkUseCase(
        email: any(named: 'email'),
        code: any(named: 'code'),
      ),
    );

    await unmountForgot(tester);
  });

  testWidgets('código rechazado por el server: casillas en rojo '
      '(InvalidCodeFailure), dígitos conservados — toast por listener', (
    tester,
  ) async {
    when(
      () => checkUseCase(
        email: any(named: 'email'),
        code: any(named: 'code'),
      ),
    ).thenAnswer(
      (_) async => const Left<AuthFailure, void>(InvalidCodeFailure()),
    );
    await pumpForgot(tester);
    await tester.pump();

    await goToStep2(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await pumpStepTransition(tester);

    // Sigue en el paso 2 con las 6 casillas pintadas en rojo — el error
    // queda donde se corrige (convención verify-email).
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.text('Crea tu nueva contraseña'), findsNothing);
    for (var i = 0; i < 6; i++) {
      expect(cellBorderColor(tester, i), errorColor(), reason: 'casilla $i');
    }
    // Los dígitos se conservan: siguen vivos en el server (corregir o
    // reenviar sobre lo tipeado).
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '123456',
    );

    await unmountForgot(tester);
  });

  testWidgets('código completo auto-avanza al paso 3 (nueva clave)', (
    tester,
  ) async {
    await pumpForgot(tester);
    await tester.pump();

    await goToStep3(tester);

    expect(find.text('Crea tu nueva contraseña'), findsOneWidget);
    expect(find.text('Elige una que no uses en otro lado.'), findsOneWidget);
    expect(find.text('Nueva contraseña *'), findsOneWidget);
    expect(find.text('Confirmar contraseña *'), findsOneWidget);
    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
    expect(find.text('Cambiar contraseña'), findsOneWidget);
    expect(find.text('Atrás'), findsOneWidget);
    verify(() => checkUseCase(email: 'ana@ejemplo.com', code: '123456'))
        .called(1);

    await unmountForgot(tester);
  });

  testWidgets('paso 3: confirmación distinta muestra "no coinciden"', (
    tester,
  ) async {
    await pumpForgot(tester);
    await tester.pump();

    await goToStep3(tester);
    await fillStep3(tester, confirm: 'otra12345');
    await tapPrimary(tester, 'Cambiar contraseña');

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    // Sigue en el paso 3 — validación local, no llamó al reset.
    expect(find.text('Crea tu nueva contraseña'), findsOneWidget);
    verifyNever(
      () => resetUseCase(
        email: any(named: 'email'),
        code: any(named: 'code'),
        newPassword: any(named: 'newPassword'),
      ),
    );

    await unmountForgot(tester);
  });

  testWidgets('submit con código expirado entre check y submit (la '
      'carrera real): REBOTA al paso 2 con el OTP en rojo (§012)', (
    tester,
  ) async {
    when(
      () => resetUseCase(
        email: any(named: 'email'),
        code: any(named: 'code'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer(
      (_) async => const Left<AuthFailure, User>(InvalidCodeFailure()),
    );
    await pumpForgot(tester);
    await tester.pump();

    await goToStep3(tester);
    await fillStep3(tester);
    await tapPrimary(tester, 'Cambiar contraseña');

    // Rebote: vuelve a "Revisa tu correo" con los dígitos en rojo — el
    // error queda donde se corrige (mismo patrón que el 409 de register).
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.text('Crea tu nueva contraseña'), findsNothing);
    for (var i = 0; i < 6; i++) {
      expect(cellBorderColor(tester, i), errorColor(), reason: 'casilla $i');
    }

    await unmountForgot(tester);
  });

  testWidgets('"Atrás" en paso 2 vuelve a paso 1 conservando el correo', (
    tester,
  ) async {
    await pumpForgot(tester);
    await tester.pump();

    await goToStep2(tester);
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.text('Atrás'), findsOneWidget);

    await tapBackStep(tester);

    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    // El correo sobrevivió al ida y vuelta (controller en el State).
    expect(find.text('ana@ejemplo.com'), findsOneWidget);

    await unmountForgot(tester);
  });

  testWidgets('"Atrás" en paso 3 vuelve al paso 2', (tester) async {
    await pumpForgot(tester);
    await tester.pump();

    await goToStep3(tester);
    expect(find.text('Crea tu nueva contraseña'), findsOneWidget);

    await tapBackStep(tester);

    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNWidgets(6));

    await unmountForgot(tester);
  });

  testWidgets('back nativo en paso 2 retrocede al paso 1 (no sale)', (
    tester,
  ) async {
    await pumpForgot(tester);
    await tester.pump();

    await goToStep2(tester);
    expect(find.text('Revisa tu correo'), findsOneWidget);

    // Botón/gesto atrás de Android — PopScope intercepta y hace prevStep.
    await tester.binding.handlePopRoute();
    await pumpStepTransition(tester);

    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('Revisa tu correo'), findsNothing);

    await unmountForgot(tester);
  });

  testWidgets('back nativo en paso 1 abandona a /login', (tester) async {
    // Entrada real: push desde login — el back POPEA a la pantalla
    // anterior conservando su stack.
    await pumpForgotWithRouter(tester, pushForgot: true);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('PANTALLA LOGIN'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsNothing);
  });

  testWidgets('flecha en paso 2 abandona a /login (no retrocede de paso)', (
    tester,
  ) async {
    await pumpForgotWithRouter(tester);
    await goToStep2(tester);
    expect(find.text('Revisa tu correo'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await pumpStepTransition(tester);

    // La flecha sale de la recuperación en CUALQUIER paso — el cambio de
    // ruta desmonta el cubit (cooldown cancelado al cerrar).
    expect(find.text('PANTALLA LOGIN'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsNothing);
  });

  testWidgets('link "Inicia sesión" abandona a /login', (tester) async {
    await pumpForgotWithRouter(tester);
    await tester.pump();

    await tester.ensureVisible(find.text('Inicia sesión'));
    await tester.tap(find.text('Inicia sesión'));
    await tester.pumpAndSettle();

    expect(find.text('PANTALLA LOGIN'), findsOneWidget);
  });

  testWidgets('entrar al paso 2 arranca el cooldown; al expirar, '
      'reenviar (forgotPassword otra vez) lo reinicia en 60s', (tester) async {
    await pumpForgot(tester);
    await tester.pump();

    await goToStep2(tester);
    // Ya corre desde el envío inicial — sin botón "Reenviar" visible.
    expect(find.text('Reenviar en 60s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Reenviar en 58s'), findsOneWidget);

    // Expira → el botón vuelve habilitado.
    await tester.pump(const Duration(seconds: 59));
    await tester.pump();
    expect(find.text('Reenviar'), findsOneWidget);

    // Reenvío real: isResending → éxito → cooldown 60 de nuevo.
    await tester.tap(find.text('Reenviar'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Reenviar en 60s'), findsOneWidget);
    verify(() => forgotUseCase(email: 'ana@ejemplo.com')).called(2);

    // Drena el timer para no dejarlo pendiente al terminar el test.
    await tester.pump(const Duration(seconds: 61));
    await unmountForgot(tester);
  });

  testWidgets('cambiar contraseña: reset OK → auto-login real → /home', (
    tester,
  ) async {
    await pumpForgotWithRouter(tester);

    await goToStep3(tester);
    await fillStep3(tester);
    await tapPrimary(tester, 'Cambiar contraseña');
    await pumpStepTransition(tester);

    // Éxito real: el usuario del endpoint marca la sesión (el guard deja
    // entrar a /home — los tokens ya los persistió el repo).
    expect(find.text('PANTALLA HOME'), findsOneWidget);
    expect(authSession.isAuthenticated, isTrue);
    expect(authSession.currentUser, user);
    verify(
      () => resetUseCase(
        email: 'ana@ejemplo.com',
        code: '123456',
        newPassword: 'secreto123',
      ),
    ).called(1);
  });
}
