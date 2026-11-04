import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/home/presentation/data/catalog_mock.dart';
import 'package:depredadog_app/features/home/presentation/screens/product_detail_screen.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  Future<void> pumpDetail(WidgetTester tester, CatalogItem item) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: ProductDetailScreen(item: item),
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

  final cachorro = catalogMockItems.firstWhere((i) => i.id == 'cachorro');

  testWidgets('renderiza datos del producto y las 4 secciones', (tester) async {
    await pumpDetail(tester, cachorro);
    await tester.pumpAndSettle();

    expect(find.text('El Cachorro'), findsOneWidget);
    expect(find.text(r'$14.000'), findsNWidgets(2)); // base + total
    expect(find.text('¿Se le quita algo?'), findsOneWidget);
    expect(find.text('¿Le agregamos algo más?'), findsOneWidget);
    expect(find.text('Agregar al carrito'), findsOneWidget);
    // Las secciones de abajo son lazy — hay que scrollear a ellas.
    await tester.scrollUntilVisible(find.text('Salsas'), 200);
    expect(find.text('Toppings'), findsOneWidget);
  });

  testWidgets('quitar un ingrediente propio lo tacha', (tester) async {
    await pumpDetail(tester, cachorro);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Huevo de codorniz'));
    await tester.pump();

    final text = tester.widget<Text>(find.text('Huevo de codorniz'));
    expect(text.style?.decoration, TextDecoration.lineThrough);
    expect(find.byIcon(Icons.remove_circle_outline_rounded), findsOneWidget);
  });

  testWidgets('agregar un adicional actualiza el total', (tester) async {
    // La pantalla es larga (~1400px) — superficie alta para que todas
    // las rows queden dentro del viewport sin scroll.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpDetail(tester, cachorro);
    await tester.pumpAndSettle();

    // Tocineta no es ingrediente propio del Cachorro → adicional +$4.000.
    await tester.tap(find.text('Tocineta crocante'));
    await tester.pump();

    expect(find.text(r'$18.000'), findsOneWidget); // 14.000 + 4.000
  });

  testWidgets('CTA dispara toast provisional', (tester) async {
    const channel = MethodChannel('PonnamKarthik/fluttertoast');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await pumpDetail(tester, cachorro);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agregar al carrito'));
    await tester.pump();
    expect(calls, hasLength(1));
    expect(calls.first.arguments['msg'], 'Disponible próximamente');

    await tester.pump(const Duration(seconds: 2));
  });
}
