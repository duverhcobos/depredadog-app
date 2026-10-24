import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/screens/welcome_screen.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  testWidgets('WelcomeScreen muestra marca y textos localizados',
      (tester) async {
    await tester.pumpWidget(
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
        home: const WelcomeScreen(),
      ),
    );

    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    expect(find.text('Bienvenido a Depredadog'), findsOneWidget);
    expect(find.text('Acceso disponible muy pronto'), findsOneWidget);
  });
}
