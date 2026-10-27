import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/login_cubit.dart';
import 'package:depredadog_app/features/auth/presentation/screens/login_screen.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  final locator = GetIt.instance;

  setUp(() {
    locator.registerFactory<LoginCubit>(() => LoginCubit());
  });

  tearDown(() async {
    await locator.reset();
  });

  Future<void> pumpLogin(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
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

  testWidgets('submit válido: loading → snackbar demo', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'nombre@ejemplo.com'),
      'test@depredadog.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secreto1');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(); // frame del snackbar

    expect(
      find.text('Inicio de sesión simulado — sin backend todavía'),
      findsOneWidget,
    );
  });
}
