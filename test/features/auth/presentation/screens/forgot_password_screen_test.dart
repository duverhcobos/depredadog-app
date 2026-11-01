import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:depredadog_app/core/auth/auth_session.dart';
import 'package:depredadog_app/core/di/setup_di.dart';
import 'package:depredadog_app/core/routes/auth_guard.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/forgot_password_cubit.dart';
import 'package:depredadog_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  // La pantalla resuelve su cubit por locator: hace falta AuthSession
  // real (el éxito simulado la marca para que /home sea alcanzable).
  // Registro mínimo por test — locator.reset() limpia todo al final.
  setUp(() {
    locator.registerLazySingleton<AuthSession>(AuthSession.new);
    locator.registerFactory<ForgotPasswordCubit>(
      () => ForgotPasswordCubit(authSession: locator<AuthSession>()),
    );
  });

  tearDown(() => locator.reset());
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

  /// Tap del botón primario del paso visible (queda dentro del scroll).
  Future<void> tapPrimary(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pump();
    await tester.tap(find.text(label));
    // pumpAndSettle cubre la transición AnimatedSwitcher (~250ms) y el
    // delay simulado del submit.
    await tester.pumpAndSettle();
  }

  /// Tap del "Atrás" secundario (TextButton, dentro del scroll igual
  /// que el primario).
  Future<void> tapBackStep(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Atrás'));
    await tester.pump();
    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
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

  /// Diligencia el paso 1 (correo) y avanza al paso 2.
  Future<void> goToStep2(
    WidgetTester tester, {
    String email = 'ana@ejemplo.com',
  }) async {
    await tester.enterText(find.byKey(const ValueKey('forgot_email')), email);
    await tapPrimary(tester, 'Enviar código');
  }

  /// Diligencia el paso 2 (código completo) — el auto-submit del 6to
  /// dígito ya avanza al paso 3.
  Future<void> goToStep3(WidgetTester tester) async {
    await goToStep2(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();
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
  });

  testWidgets('paso 2: OTP de 6 casillas + email en el subtítulo + '
      'reenviar', (tester) async {
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
    expect(find.text('Reenviar'), findsOneWidget);
    expect(find.text('Atrás'), findsOneWidget);
    // El teclado NO se abre solo al entrar al paso: el campo oculto no
    // tiene foco (autofocus:false — distinto de verify-email).
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isNot(true),
    );
  });

  testWidgets('verificar con código incompleto no avanza del paso 2', (
    tester,
  ) async {
    await pumpForgot(tester);
    await tester.pump();

    await goToStep2(tester);
    await tester.enterText(find.byType(TextField), '123');
    await tapPrimary(tester, 'Verificar');

    // Sigue en el paso 2 (la validación es por paso).
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.text('Crea tu nueva contraseña'), findsNothing);
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
    // Sigue en el paso 3.
    expect(find.text('Crea tu nueva contraseña'), findsOneWidget);
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
  });

  testWidgets('"Atrás" en paso 3 vuelve al paso 2', (tester) async {
    await pumpForgot(tester);
    await tester.pump();

    await goToStep3(tester);
    expect(find.text('Crea tu nueva contraseña'), findsOneWidget);

    await tapBackStep(tester);

    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNWidgets(6));
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
    await tester.pumpAndSettle();

    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('Revisa tu correo'), findsNothing);
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
    await tester.pumpAndSettle();

    // La flecha sale de la recuperación en CUALQUIER paso.
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

  testWidgets('reenviar arranca cooldown de 60s y deshabilita el botón', (
    tester,
  ) async {
    await pumpForgot(tester);
    await tester.pump();

    await goToStep2(tester);

    await tester.tap(find.text('Reenviar'));
    // El reenvío simulado espera simulatedDelay (800ms) antes de arrancar
    // el cooldown — pump fijo, NO pumpAndSettle: el timer periódico de
    // la cuenta regresiva nunca deja "settled" el árbol.
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Reenviar en 60s'), findsOneWidget);
    expect(find.text('Reenviar'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Reenviar en 58s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 58));
    await tester.pump();
    expect(find.text('Reenviar'), findsOneWidget);
  });

  testWidgets('cambiar contraseña: éxito simulado → navega a /home', (
    tester,
  ) async {
    await pumpForgotWithRouter(tester);

    await goToStep3(tester);
    await fillStep3(tester);
    await tapPrimary(tester, 'Cambiar contraseña');
    // pumpAndSettle (dentro de tapPrimary) resuelve el delay simulado
    // y la transición de la ruta destino.
    expect(find.text('PANTALLA HOME'), findsOneWidget);
  });
}
