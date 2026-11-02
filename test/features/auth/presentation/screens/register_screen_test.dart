import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/core/routes/auth_guard.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/register_use_case.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/register_cubit.dart';
import 'package:depredadog_app/features/auth/presentation/screens/register_screen.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

void main() {
  // RegisterScreen resuelve su cubit vía locator (propuesta 010) — los
  // tests registran la factory con el use case mockeado, patrón
  // login/verify-email.
  final locator = GetIt.instance;
  late MockRegisterUseCase registerUseCase;

  const user = User(
    id: 'u1',
    email: 'ana@ejemplo.com',
    firstName: 'Ana',
    firstLastName: 'Pérez',
    role: 'customer',
    status: 'pending_verification',
  );

  void stubRegister(Either<AuthFailure, User> result) => when(
    () => registerUseCase(
      email: any(named: 'email'),
      password: any(named: 'password'),
      firstName: any(named: 'firstName'),
      secondName: any(named: 'secondName'),
      firstLastName: any(named: 'firstLastName'),
      secondLastName: any(named: 'secondLastName'),
      phone: any(named: 'phone'),
    ),
  ).thenAnswer((_) async => result);

  setUp(() {
    registerUseCase = MockRegisterUseCase();
    // Default benigno: el registro devuelve el usuario creado — los tests
    // de UI que ejercen el submit lo re-stubbean según el caso.
    stubRegister(const Right(user));
    locator.registerFactory<RegisterCubit>(
      () => RegisterCubit(registerUseCase: registerUseCase),
    );
  });

  tearDown(() async {
    await locator.reset();
  });

  Future<void> pumpRegister(WidgetTester tester) {
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
        home: const RegisterScreen(),
      ),
    );
  }

  /// Tap del botón primario del paso visible (queda dentro del scroll).
  /// ensureVisible + pumpAndSettle: el scroll animado debe TERMINAR —
  /// con un solo pump el viewport quedaba a medio camino y el tap caía
  /// fuera del clip (el bloque Google §013 hizo el paso 1 más alto).
  Future<void> tapPrimary(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    // pumpAndSettle cubre la transición AnimatedSwitcher (~250ms).
    await tester.pumpAndSettle();
  }

  /// Tap del "Atrás" secundario (TextButton, dentro del scroll igual
  /// que el primario).
  Future<void> tapBackStep(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Atrás'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
  }

  /// RegisterScreen con un GoRouter real: los tests que verifican
  /// navegación (flecha → /login, submit → /verify-email) necesitan las
  /// rutas destino registradas (patrón login_screen_test).
  Future<void> pumpRegisterWithRouter(WidgetTester tester) {
    final router = GoRouter(
      initialLocation: AuthGuard.registerRoute,
      routes: [
        GoRoute(
          path: AuthGuard.registerRoute,
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: AuthGuard.loginRoute,
          builder: (context, state) =>
              const Scaffold(body: Text('PANTALLA LOGIN')),
        ),
        GoRoute(
          path: AuthGuard.verifyEmailRoute,
          builder: (context, state) =>
              const Scaffold(body: Text('PANTALLA VERIFY')),
        ),
      ],
    );
    return tester.pumpWidget(
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
  }

  /// Diligencia el paso 1 completo (solo nombres requeridos por defecto).
  Future<void> fillStep1(
    WidgetTester tester, {
    String firstName = 'Ana',
    String? secondName,
    String firstLastName = 'Pérez',
    String? secondLastName,
    String? phone,
  }) async {
    await tester.enterText(
      find.byKey(const ValueKey('register_first_name')),
      firstName,
    );
    if (secondName != null) {
      await tester.enterText(
        find.byKey(const ValueKey('register_second_name')),
        secondName,
      );
    }
    await tester.enterText(
      find.byKey(const ValueKey('register_first_last_name')),
      firstLastName,
    );
    if (secondLastName != null) {
      await tester.enterText(
        find.byKey(const ValueKey('register_second_last_name')),
        secondLastName,
      );
    }
    if (phone != null) {
      await tester.enterText(
        find.byKey(const ValueKey('register_phone')),
        phone,
      );
    }
  }

  /// Diligencia el paso 2 con credenciales válidas.
  Future<void> fillStep2(
    WidgetTester tester, {
    String email = 'ana@ejemplo.com',
    String password = 'secreto123',
    String? confirm,
  }) async {
    await tester.enterText(find.byKey(const ValueKey('register_email')), email);
    await tester.enterText(
      find.byKey(const ValueKey('register_password')),
      password,
    );
    await tester.enterText(
      find.byKey(const ValueKey('register_confirm_password')),
      confirm ?? password,
    );
  }

  testWidgets('paso 1: stepper, campos de datos y acciones persistentes '
      '(sin imagotipo)', (tester) async {
    await pumpRegister(tester);
    await tester.pump();

    // Stepper visual con sus 3 labels.
    expect(find.text('Datos'), findsOneWidget);
    expect(find.text('Cuenta'), findsOneWidget);
    expect(find.text('Revisión'), findsOneWidget);
    // Título del paso 1 — sin imagotipo ni headline viejo: el ÚNICO
    // Image del paso es la G de Google del botón social (§013).
    expect(find.text('Cuéntanos quién eres'), findsOneWidget);
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(1));
    expect(
      (images.single.image as AssetImage).assetName,
      'assets/images/google_g.png',
    );
    // Solo los 5 campos del paso 1 (nombres + teléfono).
    expect(find.byType(TextFormField), findsNWidgets(5));
    expect(find.text('Primer nombre *'), findsOneWidget);
    expect(find.text('Segundo nombre (opcional)'), findsOneWidget);
    expect(find.text('Primer apellido *'), findsOneWidget);
    expect(find.text('Segundo apellido (opcional)'), findsOneWidget);
    expect(find.text('Teléfono (opcional)'), findsOneWidget);
    // Acciones persistentes.
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('paso 1: el botón "Atrás" no existe (primario a todo el '
      'ancho)', (tester) async {
    await pumpRegister(tester);
    await tester.pump();

    expect(find.text('Atrás'), findsNothing);
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('paso 1: botón Google con divisor; pasos 2-3 NO lo muestran '
      '(decisión del usuario)', (tester) async {
    await pumpRegister(tester);
    await tester.pump();

    // Paso 1: espejo de login — divisor "o continúa con" + botón outlined.
    expect(find.text('o continúa con'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);

    // Paso 2: ya comprometido con el formulario — Google desaparece.
    await fillStep1(tester);
    await tapPrimary(tester, 'Continuar');
    expect(find.text('Tu correo y tu contraseña'), findsOneWidget);
    expect(find.text('o continúa con'), findsNothing);
    expect(find.text('Continuar con Google'), findsNothing);

    // Paso 3: igual.
    await fillStep2(tester);
    await tapPrimary(tester, 'Continuar');
    expect(find.text('o continúa con'), findsNothing);
    expect(find.text('Continuar con Google'), findsNothing);
  });

  testWidgets('flecha de volver queda fija arriba, fuera del scroll', (
    tester,
  ) async {
    await pumpRegister(tester);
    await tester.pump();

    final arrowTopLeft = tester.getTopLeft(find.byIcon(Icons.arrow_back));
    expect(arrowTopLeft.dy, lessThan(80));
  });

  testWidgets('continuar en paso 1 vacío: errores solo en campos del paso', (
    tester,
  ) async {
    await pumpRegister(tester);
    await tester.pump();

    await tapPrimary(tester, 'Continuar');

    expect(find.text('Ingresa tu nombre'), findsOneWidget);
    expect(find.text('Ingresa tu apellido'), findsOneWidget);
    // Los campos de cuenta no existen todavía (están en el paso 2).
    expect(find.text('Ingresa tu correo'), findsNothing);
    expect(find.text('Ingresa una contraseña'), findsNothing);
    expect(find.text('Confirma tu contraseña'), findsNothing);
    expect(find.text('Máximo 20 caracteres'), findsNothing);
  });

  testWidgets('paso 1 válido → paso 2 con sus campos', (tester) async {
    await pumpRegister(tester);
    await tester.pump();

    await fillStep1(tester);
    await tapPrimary(tester, 'Continuar');

    expect(find.text('Tu correo y tu contraseña'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('Correo electrónico *'), findsOneWidget);
    expect(find.text('Contraseña *'), findsOneWidget);
    expect(find.text('Confirmar contraseña *'), findsOneWidget);
    // Helper persistente bajo contraseña.
    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
  });

  testWidgets('paso 2: confirmación distinta muestra "no coinciden"', (
    tester,
  ) async {
    await pumpRegister(tester);
    await tester.pump();

    await fillStep1(tester);
    await tapPrimary(tester, 'Continuar');
    await fillStep2(tester, confirm: 'otra12345');
    await tapPrimary(tester, 'Continuar');

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    // Sigue en el paso 2.
    expect(find.text('Tu correo y tu contraseña'), findsOneWidget);
  });

  testWidgets('"Atrás" en paso 2 vuelve a paso 1 conservando lo tipeado', (
    tester,
  ) async {
    await pumpRegister(tester);
    await tester.pump();

    await fillStep1(tester, phone: '3001234567');
    await tapPrimary(tester, 'Continuar');
    expect(find.text('Tu correo y tu contraseña'), findsOneWidget);
    expect(find.text('Atrás'), findsOneWidget);

    await tapBackStep(tester);

    expect(find.text('Cuéntanos quién eres'), findsOneWidget);
    // Los datos sobrevivieron al ida y vuelta (controllers en el State).
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Pérez'), findsOneWidget);
    expect(find.text('3001234567'), findsOneWidget);
  });

  testWidgets('"Atrás" en paso 3 vuelve al paso 2', (tester) async {
    await pumpRegister(tester);
    await tester.pump();

    await fillStep1(tester);
    await tapPrimary(tester, 'Continuar');
    await fillStep2(tester);
    await tapPrimary(tester, 'Continuar');
    expect(find.text('Todo listo, Ana'), findsOneWidget);
    expect(find.text('Atrás'), findsOneWidget);

    await tapBackStep(tester);

    expect(find.text('Tu correo y tu contraseña'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
  });

  testWidgets('flecha en paso 2 abandona a /login (no retrocede de paso)', (
    tester,
  ) async {
    await pumpRegisterWithRouter(tester);
    await tester.pump();

    await fillStep1(tester);
    await tapPrimary(tester, 'Continuar');
    expect(find.text('Tu correo y tu contraseña'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // La flecha sale del registro en CUALQUIER paso — no vuelve al 1.
    expect(find.text('PANTALLA LOGIN'), findsOneWidget);
    expect(find.text('Cuéntanos quién eres'), findsNothing);
  });

  testWidgets(
    'paso 3: revisión con nombre compuesto, correo y "Sin teléfono"',
    (tester) async {
      await pumpRegister(tester);
      await tester.pump();

      await fillStep1(tester, secondName: 'María', secondLastName: 'Gómez');
      await tapPrimary(tester, 'Continuar');
      await fillStep2(tester);
      await tapPrimary(tester, 'Continuar');

      // Título personalizado + subtítulo de revisión.
      expect(find.text('Todo listo, Ana'), findsOneWidget);
      expect(find.text('Revisa que todo esté bien.'), findsOneWidget);
      // Tarjeta sin inputs: nombre compuesto de los 4 campos no-vacíos.
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Nombre'), findsOneWidget);
      expect(find.text('Ana María Pérez Gómez'), findsOneWidget);
      expect(find.text('Correo'), findsOneWidget);
      expect(find.text('ana@ejemplo.com'), findsOneWidget);
      expect(find.text('Teléfono'), findsOneWidget);
      expect(find.text('Sin teléfono'), findsOneWidget);
      // La contraseña nunca se muestra.
      expect(find.text('secreto123'), findsNothing);
      expect(find.text('Crear cuenta'), findsOneWidget);
      expect(find.text('Inicia sesión'), findsOneWidget);
    },
  );

  testWidgets('crear cuenta: éxito → navega a /verify-email con el email', (
    tester,
  ) async {
    await pumpRegisterWithRouter(tester);
    await tester.pump();

    await fillStep1(tester, phone: '3001234567');
    await tapPrimary(tester, 'Continuar');
    await fillStep2(tester);
    await tapPrimary(tester, 'Continuar');

    // Revisión con teléfono diligenciado.
    expect(find.text('3001234567'), findsOneWidget);
    await tapPrimary(tester, 'Crear cuenta');
    // pumpAndSettle (dentro de tapPrimary) resuelve el use case mockeado
    // y la transición de la ruta destino.
    expect(find.text('PANTALLA VERIFY'), findsOneWidget);
    verify(
      () => registerUseCase(
        email: 'ana@ejemplo.com',
        password: 'secreto123',
        firstName: 'Ana',
        secondName: null,
        firstLastName: 'Pérez',
        secondLastName: null,
        phone: '3001234567',
      ),
    ).called(1);
  });

  testWidgets(
    '409 correo duplicado: vuelve al paso 2 con "Este correo ya tiene '
    'cuenta" bajo Correo',
    (tester) async {
      stubRegister(const Left(EmailAlreadyRegisteredFailure()));
      await pumpRegister(tester);
      await tester.pump();

      await fillStep1(tester);
      await tapPrimary(tester, 'Continuar');
      await fillStep2(tester);
      await tapPrimary(tester, 'Continuar');
      expect(find.text('Todo listo, Ana'), findsOneWidget);

      await tapPrimary(tester, 'Crear cuenta');

      // Volvió al paso 2 (el error queda donde se corrige) con el correo
      // marcado — el mensaje del 409 prima sobre el de formato.
      expect(find.text('Tu correo y tu contraseña'), findsOneWidget);
      expect(find.text('Este correo ya tiene cuenta'), findsOneWidget);
      // Los otros campos del paso no se marcaron.
      expect(find.text('Ingresa una contraseña'), findsNothing);
      expect(find.text('Confirma tu contraseña'), findsNothing);
    },
  );

  testWidgets('flecha de volver en paso 1 sin stack navega a /login', (
    tester,
  ) async {
    // Acceso directo (deep link): no hay nada que popear — la flecha
    // cae al fallback context.go(/login).
    await pumpRegisterWithRouter(tester);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('PANTALLA LOGIN'), findsOneWidget);
  });
}
