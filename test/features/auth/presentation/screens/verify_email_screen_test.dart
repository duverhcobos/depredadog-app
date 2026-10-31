import 'package:flutter/material.dart';
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
import 'package:depredadog_app/features/auth/domain/use_cases/resend_verification_use_case.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/verify_email_use_case.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/verify_email_cubit.dart';
import 'package:depredadog_app/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

class MockVerifyEmailUseCase extends Mock implements VerifyEmailUseCase {}

class MockResendVerificationUseCase extends Mock
    implements ResendVerificationUseCase {}

void main() {
  final locator = GetIt.instance;

  late MockVerifyEmailUseCase verifyUseCase;
  late MockResendVerificationUseCase resendUseCase;
  late AuthSession authSession;

  const user = User(
    id: 'u1',
    email: 'correo@ejemplo.com',
    firstName: 'Test',
    firstLastName: 'User',
    role: 'customer',
    status: 'active',
  );

  setUp(() {
    verifyUseCase = MockVerifyEmailUseCase();
    resendUseCase = MockResendVerificationUseCase();
    authSession = AuthSession();
    // Defaults benignos: resend siempre responde 200 (anti-enumeración) y
    // verify devuelve sesión — los tests de UI no ejercen submit, pero un
    // llamado no stubeado de mocktail explotaría el pump.
    when(() => resendUseCase(email: any(named: 'email')))
        .thenAnswer((_) async => const Right<AuthFailure, void>(null));
    when(
      () => verifyUseCase(
        email: any(named: 'email'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) async => const Right<AuthFailure, User>(user));
    locator.registerFactoryParam<VerifyEmailCubit, String, void>(
      (email, _) => VerifyEmailCubit(
        email: email,
        verifyEmailUseCase: verifyUseCase,
        resendVerificationUseCase: resendUseCase,
        authSession: authSession,
      ),
    );
  });

  tearDown(() async {
    await locator.reset();
  });

  Future<void> pumpVerifyEmail(WidgetTester tester) {
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
        home: const VerifyEmailScreen(email: 'correo@ejemplo.com'),
      ),
    );
  }

  testWidgets('renderiza sin errores de árbol (casillas + campo oculto)', (
    tester,
  ) async {
    await pumpVerifyEmail(tester);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Verifica tu correo'), findsOneWidget);
    expect(
      find.text('Enviamos un código de 6 dígitos a correo@ejemplo.com'),
      findsOneWidget,
    );
    // 6 casillas renderizadas + el TextField invisible que captura el teclado.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNWidgets(6));
    expect(find.text('Verificar'), findsOneWidget);
    expect(find.text('Reenviar'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('flecha de volver queda fija arriba, fuera del bloque centrado', (
    tester,
  ) async {
    await pumpVerifyEmail(tester);
    await tester.pump();

    final arrowTopLeft = tester.getTopLeft(find.byIcon(Icons.arrow_back));
    expect(arrowTopLeft.dy, lessThan(80));
  });

  testWidgets('reenviar arranca cooldown de 60s y deshabilita el botón', (
    tester,
  ) async {
    await pumpVerifyEmail(tester);
    await tester.pump();

    await tester.tap(find.text('Reenviar'));
    // El mock resuelve Right(null) — el cubit arranca el cooldown apenas
    // regresa el future del use case.
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Reenviar en 60s'), findsOneWidget);
    expect(find.text('Reenviar'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Reenviar en 58s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 58));
    await tester.pump();
    expect(find.text('Reenviar'), findsOneWidget);
  });

  testWidgets('email vacío en extra redirige a /login', (tester) async {
    // La ruta solo se alcanza legítimamente desde login con el email como
    // extra — un acceso directo sin email devuelve al login (guard §004).
    final router = GoRouter(
      initialLocation: AuthGuard.verifyEmailRoute,
      routes: [
        GoRoute(
          path: AuthGuard.verifyEmailRoute,
          builder: (context, state) =>
              VerifyEmailScreen(email: (state.extra as String?) ?? ''),
        ),
        GoRoute(
          path: AuthGuard.loginRoute,
          builder: (context, state) =>
              const Scaffold(body: Text('PANTALLA LOGIN')),
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

    expect(find.text('PANTALLA LOGIN'), findsOneWidget);
    expect(find.text('Verifica tu correo'), findsNothing);
  });
}
