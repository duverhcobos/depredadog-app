import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:depredadog_app/core/auth/auth_session.dart';
import 'package:depredadog_app/core/routes/auth_guard.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/login_use_case.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/login_cubit.dart';
import 'package:depredadog_app/features/auth/presentation/screens/login_screen.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}

void main() {
  final locator = GetIt.instance;
  late MockLoginUseCase loginUseCase;
  late AuthSession authSession;

  const user = User(
    id: 'u1',
    email: 'test@depredadog.com',
    firstName: 'Test',
    lastName: 'User',
    role: 'customer',
    status: 'active',
  );

  setUp(() {
    loginUseCase = MockLoginUseCase();
    authSession = AuthSession();
    locator.registerFactory<LoginCubit>(
      () => LoginCubit(loginUseCase: loginUseCase, authSession: authSession),
    );
  });

  tearDown(() async {
    await locator.reset();
  });

  Future<void> pumpLogin(WidgetTester tester) {
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
        home: const LoginScreen(),
      ),
    );
  }

  testWidgets('muestra marca, campos y acciones del mock', (tester) async {
    await pumpLogin(tester);

    expect(find.text('VUELVE A LA MANADA'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Ingresar con Google'), findsOneWidget);
    expect(find.text('Regístrate'), findsOneWidget);
    expect(find.byType(Image), findsWidgets); // imagotipo + logo G
  });

  testWidgets('submit con campos vacíos muestra errores', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });

  testWidgets('submit válido: éxito → navega a /home y marca la sesión', (
    tester,
  ) async {
    when(
      () => loginUseCase(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Right(user));

    // El éxito navega con context.go — hace falta un GoRouter real con la
    // ruta destino registrada (aquí un placeholder).
    final router = GoRouter(
      initialLocation: AuthGuard.loginRoute,
      routes: [
        GoRoute(
          path: AuthGuard.loginRoute,
          builder: (context, state) => const LoginScreen(),
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

    await tester.enterText(
      find.widgetWithText(TextFormField, 'nombre@ejemplo.com'),
      'test@depredadog.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secreto1');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('PANTALLA HOME'), findsOneWidget);
    expect(authSession.isAuthenticated, isTrue);
    verify(
      () => loginUseCase(email: 'test@depredadog.com', password: 'secreto1'),
    ).called(1);
  });

  testWidgets(
    'email no verificado → descarta autofill y navega a /verify-email',
    (tester) async {
      when(
        () => loginUseCase(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Left(EmailNotVerifiedFailure()));

      // Si el contexto de autofill queda abierto, al navegar Android lo
      // "commitea" y GMS dispara el modal "¿Guardar contraseña?" que
      // compite con el teclado del OTP (bug del usuario). La pantalla
      // debe cerrarlo con shouldSave:false antes de ir a /verify-email.
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.textInput,
          null,
        ),
      );

      final router = GoRouter(
        initialLocation: AuthGuard.loginRoute,
        routes: [
          GoRoute(
            path: AuthGuard.loginRoute,
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: AuthGuard.verifyEmailRoute,
            builder: (context, state) =>
                const Scaffold(body: Text('PANTALLA VERIFY')),
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

      await tester.enterText(
        find.widgetWithText(TextFormField, 'nombre@ejemplo.com'),
        'test@depredadog.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secreto1');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('PANTALLA VERIFY'), findsOneWidget);
      expect(
        calls.any(
          (c) =>
              c.method == 'TextInput.finishAutofillContext' &&
              c.arguments == false,
        ),
        isTrue,
      );
    },
  );
}
