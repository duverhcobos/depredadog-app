import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/home/domain/entities/catalog_category.dart';
import 'package:depredadog_app/features/home/domain/entities/catalog_product.dart';
import 'package:depredadog_app/features/home/domain/entities/modifier_group.dart';
import 'package:depredadog_app/features/home/domain/entities/modifier_option.dart';
import 'package:depredadog_app/features/home/presentation/cubit/catalog_cubit.dart';
import 'package:depredadog_app/features/home/presentation/cubit/catalog_state.dart';
import 'package:depredadog_app/features/home/presentation/screens/product_detail_screen.dart';
import 'package:depredadog_app/features/home/presentation/widgets/customization_section.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

class MockCatalogCubit extends MockCubit<CatalogState>
    implements CatalogCubit {}

/// Fixture equivalente al Cachorro del mock viejo ($14.000) pero con el
/// modelo real de modifierGroups (§019):
/// - ingredients: pan y salchicha FIJOS (no removibles — pan gratis,
///   salchicha con precio de doble), mozzarella y huevo propios
///   removibles, tocineta como adicional.
/// - toppings y salsas: grupos propios con opciones gratis.
CatalogProduct _cachorro({
  bool productAvailable = true,
  bool tocinetaAvailable = true,
  bool mozzarellaAvailable = true,
  bool mozzarellaReplaceable = true,
  bool huevoAvailable = true,
  bool salchichaAvailable = true,
}) => CatalogProduct(
  id: 'p-cachorro',
  slug: 'cachorro',
  name: 'El Cachorro',
  tagline: 'El primer mordisco de la manada.',
  basePrice: 14000,
  imageUrl: null,
  isAvailable: productAvailable,
  isFeatured: false,
  isCombo: false,
  modifierGroups: [
    ModifierGroup(
      id: 'g-ing',
      slug: 'ingredients',
      name: 'Ingredientes',
      minSelect: 0,
      maxSelect: null,
      options: [
        const ModifierOption(
          id: 'o-pan',
          name: 'Pan artesanal',
          extraPrice: 0,
          isAvailable: true,
          isRemovable: false,
          includedByDefault: true,
        ),
        // La salchicha es el corazón del perro: no se regala como
        // reemplazo y es ESENCIAL — si se agota, el perro se apaga
        // (regla del usuario).
        ModifierOption(
          id: 'o-salchicha',
          name: 'Salchicha americana',
          extraPrice: 5000,
          isAvailable: salchichaAvailable,
          isRemovable: false,
          includedByDefault: true,
          isReplacementEligible: false,
          isReplaceable: false,
          isEssential: true,
        ),
        ModifierOption(
          id: 'o-mozzarella',
          name: 'Queso mozzarella',
          extraPrice: 3500,
          isAvailable: mozzarellaAvailable,
          isRemovable: true,
          includedByDefault: true,
          isReplaceable: mozzarellaReplaceable,
        ),
        ModifierOption(
          id: 'o-huevo',
          name: 'Huevo de codorniz',
          extraPrice: 2500,
          isAvailable: huevoAvailable,
          isRemovable: true,
          includedByDefault: true,
        ),
        ModifierOption(
          id: 'o-tocineta',
          name: 'Tocineta crocante',
          extraPrice: 4000,
          isAvailable: tocinetaAvailable,
          isRemovable: true,
          includedByDefault: false,
        ),
      ],
    ),
    const ModifierGroup(
      id: 'g-top',
      slug: 'toppings',
      name: 'Toppings',
      minSelect: 0,
      maxSelect: null,
      options: [
        ModifierOption(
          id: 'o-ripio',
          name: 'Papa ripio',
          extraPrice: 0,
          isAvailable: true,
          isRemovable: false,
          includedByDefault: false,
        ),
        ModifierOption(
          id: 'o-rallado',
          name: 'Queso rallado',
          extraPrice: 0,
          isAvailable: true,
          isRemovable: false,
          includedByDefault: false,
        ),
      ],
    ),
    const ModifierGroup(
      id: 'g-sau',
      slug: 'sauces',
      name: 'Salsas',
      minSelect: 0,
      maxSelect: null,
      options: [
        ModifierOption(
          id: 'o-ketchup',
          name: 'Ketchup',
          extraPrice: 0,
          isAvailable: true,
          isRemovable: false,
          includedByDefault: false,
        ),
        ModifierOption(
          id: 'o-mayo',
          name: 'Mayonesa',
          extraPrice: 0,
          isAvailable: true,
          isRemovable: false,
          includedByDefault: false,
        ),
      ],
    ),
  ],
);

CatalogState _stateWith(CatalogProduct product) => CatalogState(
  status: CatalogStatus.success,
  categories: [
    CatalogCategory(
      id: 'cat-perros',
      slug: 'perros',
      name: 'Perros',
      products: [product],
    ),
  ],
);

void main() {
  late MockCatalogCubit cubit;

  setUp(() {
    cubit = MockCatalogCubit();
    when(() => cubit.refresh()).thenAnswer((_) async {});
  });

  Future<void> pumpDetail(
    WidgetTester tester,
    String slug,
    CatalogState state,
  ) {
    whenListen(cubit, const Stream<CatalogState>.empty(), initialState: state);
    return tester.pumpWidget(
      BlocProvider<CatalogCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: ProductDetailScreen(productSlug: slug),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
        ),
      ),
    );
  }

  testWidgets('renderiza datos del producto y las secciones', (tester) async {
    await pumpDetail(tester, 'cachorro', _stateWith(_cachorro()));
    await tester.pumpAndSettle();

    expect(find.text('El Cachorro'), findsOneWidget);
    expect(find.text(r'$14.000'), findsNWidgets(2)); // base + total
    expect(find.text('¿Se le quita algo?'), findsOneWidget);
    expect(find.text('¿Le agregamos algo más?'), findsOneWidget);
    expect(find.text('Agregar al carrito'), findsOneWidget);

    // "¿Se le quita algo?" solo lista removibles incluidos — pan y
    // salchicha son FIJOS y no aparecen (§018/§019).
    expect(find.byType(RemovableRow), findsNWidgets(2));
    expect(find.text('Queso mozzarella'), findsOneWidget);
    expect(find.text('Huevo de codorniz'), findsOneWidget);
    // La salchicha fija SÍ sale como adicional (doble salchicha §018).
    expect(find.text('Salchicha americana'), findsOneWidget);
    expect(find.text(r'+$5.000'), findsOneWidget);
    expect(find.text(r'+$4.000'), findsOneWidget);

    // Las secciones de abajo son lazy — hay que scrollear a ellas.
    await tester.scrollUntilVisible(find.text('Salsas'), 200);
    expect(find.text('Toppings'), findsOneWidget);
    expect(find.text('Papa ripio'), findsOneWidget);
    expect(find.text('Ketchup'), findsOneWidget);
  });

  testWidgets('quitar un ingrediente propio lo tacha', (tester) async {
    await pumpDetail(tester, 'cachorro', _stateWith(_cachorro()));
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

    await pumpDetail(tester, 'cachorro', _stateWith(_cachorro()));
    await tester.pumpAndSettle();

    // Tocineta no es ingrediente propio del Cachorro → adicional +$4.000.
    await tester.tap(find.text('Tocineta crocante'));
    await tester.pump();

    expect(find.text(r'$18.000'), findsOneWidget); // 14.000 + 4.000
  });

  testWidgets('producto agotado → CTA deshabilitado con "Agotado"', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      'cachorro',
      _stateWith(_cachorro(productAvailable: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agregar al carrito'), findsNothing);
    final cta = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Agotado'),
    );
    expect(cta.onPressed, isNull);
  });

  testWidgets('opción agotada → fila gris inerte con tag "Agotado"', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpDetail(
      tester,
      'cachorro',
      _stateWith(_cachorro(tocinetaAvailable: false)),
    );
    await tester.pumpAndSettle();

    // El trailing del extra muestra "Agotado" en vez de "+$4.000".
    expect(find.text('Agotado'), findsOneWidget);
    expect(find.text(r'+$4.000'), findsNothing);
    final row = tester.widget<OptionRow>(
      find.ancestor(
        of: find.text('Tocineta crocante'),
        matching: find.byType(OptionRow),
      ),
    );
    expect(row.enabled, isFalse);

    // Tap inerte — el total no se mueve.
    await tester.tap(find.text('Tocineta crocante'));
    await tester.pump();
    expect(find.text(r'$18.000'), findsNothing);
    expect(find.text(r'$14.000'), findsNWidgets(2));
  });

  testWidgets(
    'ingrediente incluido agotado → "Cambiar" despliega reemplazo gratis',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpDetail(
        tester,
        'cachorro',
        _stateWith(_cachorro(mozzarellaAvailable: false)),
      );
      await tester.pumpAndSettle();

      // Fila agotada con el icono de intercambio junto a la X roja.
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);

      // Expandir → los adicionales aparecen en el picker (Tocineta
      // duplica: fila del picker + su OptionRow de extras). Las filas
      // del reemplazo no llevan etiqueta — sin "Gratis" en ningún lado.
      await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Tocineta crocante'), findsNWidgets(2));
      expect(find.text('Gratis'), findsNothing);

      // Elegir Tocineta como reemplazo (la primera es la fila del
      // picker — la otra es su OptionRow de extras) → el picker
      // colapsa y el reemplazo queda como fila propia bajo el
      // agotado, con colores de fila activa.
      await tester.tap(find.text('Tocineta crocante').first);
      await tester.pumpAndSettle();

      // 'Tocineta crocante' sigue 2 veces: fila elegida + extra.
      expect(find.text('Tocineta crocante'), findsNWidgets(2));
      // La fila elegida es la OptionRow sin etiqueta trailing, con
      // gancho ↳ que la subordina al agotado de arriba.
      final chosen = tester
          .widgetList<OptionRow>(
            find.ancestor(
              of: find.text('Tocineta crocante'),
              matching: find.byType(OptionRow),
            ),
          )
          .singleWhere((r) => r.trailingLabel == null);
      expect(chosen.selected, isTrue);
      expect(chosen.enabled, isTrue);
      expect(
        find.byIcon(Icons.subdirectory_arrow_right_rounded),
        findsOneWidget,
      );

      // Total intacto — el reemplazo no cobra.
      expect(find.text(r'$14.000'), findsNWidgets(2));
      expect(find.text(r'$18.000'), findsNothing);

      // Reabrir con el icono vuelve a mostrar el picker — Tocineta
      // duplica de nuevo. La salchicha NUNCA entra al picker:
      // isReplacementEligible=false (regla del usuario).
      await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Tocineta crocante'), findsNWidgets(2));
      expect(find.text('Salchicha americana'), findsOneWidget);
    },
  );

  testWidgets(
    'candidato tomado por un agotado no se repite en el picker de otro',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Dos incluidas agotadas reemplazables (mozzarella + huevo)
      // compitiendo por el MISMO pool de candidatos — en el fixture
      // solo Tocineta es elegible.
      await pumpDetail(
        tester,
        'cachorro',
        _stateWith(
          _cachorro(mozzarellaAvailable: false, huevoAvailable: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.swap_horiz_rounded), findsNWidgets(2));

      // Abrir el picker de mozzarella y elegir Tocineta.
      await tester.tap(find.byIcon(Icons.swap_horiz_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tocineta crocante').first);
      await tester.pumpAndSettle();

      // Tocineta quedó tomada por mozzarella → para huevo ya no hay
      // candidatos y su ↔ desaparece (no picker vacío); el de
      // mozzarella sigue para reabrir y cambiar su elección.
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);

      // Reabrir el picker de mozzarella: Tocineta sigue listada
      // (es SU elección) — la exclusión es solo entre agotadas.
      await tester.tap(find.byIcon(Icons.swap_horiz_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Tocineta crocante'), findsNWidgets(2));
    },
  );

  testWidgets('ingrediente agotado no reemplazable → solo X, sin ↔', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpDetail(
      tester,
      'cachorro',
      _stateWith(
        _cachorro(mozzarellaAvailable: false, mozzarellaReplaceable: false),
      ),
    );
    await tester.pumpAndSettle();

    // Agotada y no reemplazable: X roja pero SIN el control de
    // cambio — el dueño no permite sustituir este ingrediente.
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsNothing);
  });

  testWidgets('ingrediente esencial agotado → el producto entero se agota', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // El producto sigue isAvailable=true — pero la salchicha
    // (esencial, incluida) está agotada → el perro se apaga solo.
    await pumpDetail(
      tester,
      'cachorro',
      _stateWith(_cachorro(salchichaAvailable: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agregar al carrito'), findsNothing);
    final cta = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Agotado'),
    );
    expect(cta.onPressed, isNull);
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

    await pumpDetail(tester, 'cachorro', _stateWith(_cachorro()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agregar al carrito'));
    await tester.pump();
    expect(calls, hasLength(1));
    expect(calls.first.arguments['msg'], 'Disponible próximamente');

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('slug desconocido → vista "no disponible" con salida', (
    tester,
  ) async {
    await pumpDetail(tester, 'inexistente', _stateWith(_cachorro()));
    await tester.pumpAndSettle();

    expect(find.text('Este producto ya no está en la carta'), findsOneWidget);
    expect(find.text('Volver al menú'), findsOneWidget);
  });
}
