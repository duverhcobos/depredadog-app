import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/home/presentation/data/catalog_mock.dart';
import 'package:depredadog_app/features/home/presentation/screens/category_products_screen.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  Future<void> pumpList(WidgetTester tester, CatalogCategory c) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: CategoryProductsScreen(category: c),
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

  testWidgets('categoría vacía muestra Disponible próximamente', (
    tester,
  ) async {
    await pumpList(tester, CatalogCategory.combos);
    await tester.pumpAndSettle();

    expect(find.text('Combos'), findsOneWidget);
    expect(find.text('Disponible próximamente'), findsOneWidget);
  });

  testWidgets('agregar dispara toast provisional', (tester) async {
    const channel = MethodChannel('PonnamKarthik/fluttertoast');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        calls.add(call);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await pumpList(tester, CatalogCategory.more);
    await tester.pumpAndSettle();
    expect(find.text('Manada de Papas'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pump();
    expect(calls, hasLength(1));
    expect(calls.first.arguments['msg'], 'Disponible próximamente');

    await tester.pump(const Duration(seconds: 2));
  });
}
