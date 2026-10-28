import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/verify_email_cubit.dart';
import 'package:depredadog_app/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  final locator = GetIt.instance;

  setUp(() {
    locator.registerFactoryParam<VerifyEmailCubit, String, void>(
      (email, _) => VerifyEmailCubit(email: email),
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
    // El cubit simula la latencia del endpoint (600ms) antes de arrancar
    // el cooldown.
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Reenviar en 60s'), findsOneWidget);
    expect(find.text('Reenviar'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Reenviar en 58s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 58));
    await tester.pump();
    expect(find.text('Reenviar'), findsOneWidget);
  });
}
