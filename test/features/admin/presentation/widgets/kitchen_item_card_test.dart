import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/admin/domain/entities/admin_order.dart';
import 'package:depredadog_app/features/admin/presentation/utils/kitchen_order_data.dart';
import 'package:depredadog_app/features/admin/presentation/widgets/kitchen_item_card.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

/// Tests de la card-imagen de la comanda (§043 v5): tiquete
/// vertical seccionado (header → Nx nombre → secciones del ítem →
/// footer con nota y total anclado) y el render offscreen → PNG
/// por ítem que sale al share sheet.
void main() {
  final l10n = lookupAppLocalizations(const Locale('es'));

  /// path_provider → temp dir real — renderKitchenItemCards escribe
  /// las PNG (sin stub revienta: no hay plugin registrado en test).
  Directory stubPathProvider(WidgetTester tester) {
    final tmp = Directory.systemTemp.createTempSync('kitchen_cards_test');
    addTearDown(() {
      // Si el test falló con un write todavía en vuelo el dir queda
      // bloqueado (errno 32) — el tearDown no debe tapar el error real.
      try {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // noop
      }
    });
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'getTemporaryDirectory' ? tmp.path : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    return tmp;
  }

  /// La data típica de la comanda — Mesa/domicilio/pickup se
  /// parametriza por serviceLines + número.
  KitchenOrderData data({
    String number = '5',
    List<String> serviceLines = const ['Para llevar'],
    AdminPaymentMethod paymentMethod = AdminPaymentMethod.cash,
    List<KitchenOrderLine> items = const [
      KitchenOrderLine(
        quantity: 1,
        name: 'El Coyote',
        sections: [
          KitchenSection(title: 'Se le quitó', names: ['Chile con carne']),
          KitchenSection(
            title: 'Ingredientes',
            names: ['Pan', 'Salchicha americana'],
          ),
          KitchenSection(title: 'Adicionales', names: ['Piña en trozos']),
          KitchenSection(title: 'Salsas', names: ['Salsa de piña']),
        ],
      ),
      KitchenOrderLine(quantity: 2, name: 'La Trampa'),
    ],
    String? note = 'para la mesa del fondo',
    int total = 14000,
  }) => KitchenOrderData(
    number: number,
    serviceLines: serviceLines,
    paymentMethod: paymentMethod,
    placedAt: DateTime(2026, 11, 8, 12, 40),
    items: items,
    note: note,
    total: total,
  );

  /// Context con el MaterialApp real — la card renderiza dentro del
  /// Overlay de la app (mismo camino que producción).
  Future<BuildContext> pumpApp(WidgetTester tester) async {
    BuildContext? ctx;
    await tester.pumpWidget(
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
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return ctx!;
  }

  /// Corre el render bombeando frames hasta que el future resuelve —
  /// cada ítem espera un endOfFrame tras insertar su OverlayEntry.
  /// runAsync porque toImage/toByteData y el writeAsBytes de las PNG
  /// son async REAL del engine/IO: en la zona fake del testWidgets
  /// no progresan (mismo motivo por el que matchesGoldenFile
  /// envuelve captureImage en runAsync). Devuelve los paths (sin
  /// nombrar XFile — cross_file es transitivo de share_plus).
  Future<List<String>> renderPumping(
    WidgetTester tester,
    BuildContext context,
    KitchenOrderData d,
  ) async {
    List<String>? paths;
    Object? error;
    await tester.runAsync(() async {
      unawaited(
        renderKitchenItemCards(context, d, l10n).then(
          (files) => paths = [for (final f in files) f.path],
          onError: (e, s) {
            error = e;
            // ignore: avoid_print
            print('RENDER ERROR: $e\n$s');
            return null;
          },
        ),
      );
      for (var i = 0; i < 200 && paths == null && error == null; i++) {
        await tester.pump();
        // Cedé al event loop REAL: pump() resuelve por microtask y el
        // writeAsBytes/toByteData de las PNG solo llega cuando el loop
        // real corre — sin este yield el render se muere de hambre.
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    expect(error, isNull, reason: 'el render lanzó: $error');
    expect(paths, isNotNull, reason: 'el render no resolvió en 50 frames');
    return paths!;
  }

  testWidgets('la card pinta header de marca, Nx nombre, secciones '
      'con viñeta, footers, nota y total — y su boundary captura '
      'PNG no vacío (§043 v5)', (tester) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          // SingleChildScrollView: la tipografía v6 deja la card
          // más alta que el viewport del test — en producción el
          // render offscreen no tiene techo.
          body: SingleChildScrollView(
            child: Center(
              // Las secciones llegan ya armadas por la factory
              // (presentación pura — misma envoltura del render).
              child: RepaintBoundary(
                key: boundaryKey,
                child: KitchenItemCard(
                  item: const KitchenOrderLine(
                    quantity: 1,
                    name: 'El Coyote',
                    sections: [
                      KitchenSection(
                        title: 'Se le quitó',
                        names: ['Chile con carne'],
                      ),
                      KitchenSection(
                        title: 'Ingredientes',
                        names: ['Pan', 'Salchicha americana'],
                      ),
                      KitchenSection(
                        title: 'Adicionales',
                        names: ['Piña en trozos'],
                      ),
                      KitchenSection(title: 'Salsas', names: ['Salsa de piña']),
                    ],
                  ),
                  orderTag: 'PEDIDO #adm-5',
                  indexText: l10n.shareWaItemIndex(1, 2),
                  footerLines: const ['Para llevar · Efectivo · 12:40 p. m.'],
                  noteLine: 'Nota: para la mesa del fondo',
                  totalLine: r'Total del pedido: $14.000',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Header de tiquete en dos líneas centradas: wordmark Text.rich
    // y bajo él el tag + índice como metadato (§043 v4).
    expect(find.text('DEPREDADOG'), findsOneWidget);
    expect(find.text('PEDIDO #adm-5 · 1/2'), findsOneWidget);
    expect(find.text('1x El Coyote'), findsOneWidget);
    // Secciones: título + cada nombre en su línea (v5).
    expect(find.text('Se le quitó'), findsOneWidget);
    expect(find.text('Chile con carne'), findsOneWidget);
    expect(find.text('Ingredientes'), findsOneWidget);
    expect(find.text('Salchicha americana'), findsOneWidget);
    expect(find.text('Adicionales'), findsOneWidget);
    expect(find.text('Piña en trozos'), findsOneWidget);
    expect(find.text('Salsas'), findsOneWidget);
    expect(find.text('Salsa de piña'), findsOneWidget);
    expect(find.text('Para llevar · Efectivo · 12:40 p. m.'), findsOneWidget);
    expect(find.text('Nota: para la mesa del fondo'), findsOneWidget);
    expect(find.text(r'Total del pedido: $14.000'), findsOneWidget);
    // Marca de agua — el isotipo del imagotipo dark (§043 v2).
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/images/imagotipo_depredadog_dark.png',
      ),
      findsOneWidget,
    );

    final boundary =
        tester.renderObject(find.byKey(boundaryKey)) as RenderRepaintBoundary;
    // Las futures del engine (toImage/toByteData) solo resuelven en
    // la zona async real — mismo motivo por el que matchesGoldenFile
    // envuelve captureImage en runAsync.
    final image = await tester.runAsync(
      () => boundary.toImage(pixelRatio: 2.0),
    );
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    image!.dispose();
    expect(bytes!.buffer.asUint8List(), isNotEmpty);
  });

  testWidgets('ítem sin mods solo lleva su título; nota ausente y '
      'card única no gastan línea ni índice (§043)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: Center(
            child: KitchenItemCard(
              item: KitchenOrderLine(quantity: 3, name: 'El Cachorro'),
              orderTag: 'PEDIDO #adm-9',
              footerLines: ['En el local · Transf. · 1:15 p. m.'],
              totalLine: r'Total del pedido: $42.000',
            ),
          ),
        ),
      ),
    );

    expect(find.text('3x El Cachorro'), findsOneWidget);
    // Sin indexText el tag no lleva pista de posición — '1/1'
    // era ruido (revisor-ui §043).
    expect(find.text('DEPREDADOG'), findsOneWidget);
    expect(find.text('PEDIDO #adm-9'), findsOneWidget);
    expect(find.textContaining('/'), findsNothing);
    // Sin secciones no se pinta título ni viñeta (v5).
    expect(find.text('Se le quitó'), findsNothing);
    expect(find.text('Ingredientes'), findsNothing);
    expect(find.text('Adicionales'), findsNothing);
    expect(find.text('Toppings'), findsNothing);
    expect(find.text('Salsas'), findsNothing);
    // La nota vacía no se pinta — la línea entera se omite.
    expect(find.textContaining('Nota:'), findsNothing);
    expect(find.text('En el local · Transf. · 1:15 p. m.'), findsOneWidget);
  });

  testWidgets('domicilio: el footer baja la dirección y el teléfono '
      'en líneas propias (§043 v2 — el dueño reparte)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: Center(
            child: KitchenItemCard(
              item: KitchenOrderLine(quantity: 1, name: 'La Trampa'),
              orderTag: 'PEDIDO #adm-3',
              footerLines: [
                'Domicilio · Transf. · 12:40 p. m.',
                'Casa · Portón negro frente a la cancha · Barrio La Esperanza',
                'Recibe: 300 123 4567',
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Domicilio · Transf. · 12:40 p. m.'), findsOneWidget);
    expect(
      find.text('Casa · Portón negro frente a la cancha · Barrio La Esperanza'),
      findsOneWidget,
    );
    expect(find.text('Recibe: 300 123 4567'), findsOneWidget);
  });

  testWidgets('renderKitchenItemCards: un PNG no vacío por ítem con '
      'mesa, pickup y domicilio (§043 v2)', (tester) async {
    final tmp = stubPathProvider(tester);
    final ctx = await pumpApp(tester);

    final cases = <KitchenOrderData>[
      data(serviceLines: const ['Mesa 2']), // dineIn con mesa
      data(), // pickup — el default del helper
      data(
        serviceLines: const [
          'Domicilio',
          'Casa · Portón negro frente a la cancha · Barrio La Esperanza',
          'Recibe: 300 123 4567',
        ],
        paymentMethod: AdminPaymentMethod.transfer,
      ),
    ];
    for (final d in cases) {
      final paths = await renderPumping(tester, ctx, d);
      // Una imagen por ítem — la card es self-contained (§043).
      expect(paths, hasLength(d.items.length));
      for (var i = 0; i < paths.length; i++) {
        final file = File(paths[i]);
        expect(file.existsSync(), isTrue);
        expect(file.lengthSync(), greaterThan(0));
        expect(file.path, contains('${tmp.path}/pedido_5_item_${i + 1}.png'));
      }
    }
  });
}
