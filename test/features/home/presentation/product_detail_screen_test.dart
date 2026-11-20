import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_item.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';
import 'package:depredadog_app/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:depredadog_app/features/home/domain/entities/catalog_category.dart';
import 'package:depredadog_app/features/home/domain/entities/catalog_product.dart';
import 'package:depredadog_app/features/home/domain/entities/modifier_group.dart';
import 'package:depredadog_app/features/home/domain/entities/modifier_option.dart';
import 'package:depredadog_app/features/home/presentation/cubit/catalog_cubit.dart';
import 'package:depredadog_app/features/home/presentation/cubit/catalog_state.dart';
import 'package:depredadog_app/features/home/presentation/screens/product_detail_screen.dart';
import 'package:depredadog_app/features/home/presentation/widgets/customization_section.dart';
import 'package:depredadog_app/features/home/presentation/widgets/extra_stepper_row.dart';
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
  // CartCubit real (§020): sus métodos son síncronos — no hace
  // falta mock, se observa el estado directo.
  late CartCubit cartCubit;

  setUp(() {
    cubit = MockCatalogCubit();
    cartCubit = CartCubit();
    when(() => cubit.refresh()).thenAnswer((_) async {});
  });

  tearDown(() => cartCubit.close());

  Future<void> pumpDetail(
    WidgetTester tester,
    String slug,
    CatalogState state, {
    CartItem? editingItem,
  }) {
    whenListen(cubit, const Stream<CatalogState>.empty(), initialState: state);
    return tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<CatalogCubit>.value(value: cubit),
          BlocProvider<CartCubit>.value(value: cartCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: ProductDetailScreen(
            productSlug: slug,
            editingItem: editingItem,
          ),
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

  /// Variante con GoRouter real (§020): el CTA hace context.pop() —
  /// la extensión exige un GoRouter en el árbol ("No GoRouter found"),
  /// así que este caso monta la ruta '/detalle' hija de '/' para
  /// verificar también que la pantalla se desapila a la carta.
  Future<void> pumpDetailWithRouter(
    WidgetTester tester,
    String slug,
    CatalogState state, {
    CartItem? editingItem,
  }) {
    whenListen(cubit, const Stream<CatalogState>.empty(), initialState: state);
    final router = GoRouter(
      initialLocation: '/detalle',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('CARTA')),
          routes: [
            GoRoute(
              path: 'detalle',
              builder: (_, _) => ProductDetailScreen(
                productSlug: slug,
                editingItem: editingItem,
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    return tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<CatalogCubit>.value(value: cubit),
          BlocProvider<CartCubit>.value(value: cartCubit),
        ],
        child: MaterialApp.router(
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
    // §045: mozzarella y huevo duplican texto — su fila removible y
    // su ExtraStepperRow en Adicionales (incluida con precio = extra
    // cobrado al repetir).
    expect(find.text('Queso mozzarella'), findsNWidgets(2));
    expect(find.text('Huevo de codorniz'), findsNWidgets(2));
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

    // §045: 'Huevo de codorniz' sale 2× — la fila quitable es la
    // RemovableRow (la otra es su stepper de extra).
    final huevoRow = find.widgetWithText(RemovableRow, 'Huevo de codorniz');
    await tester.tap(huevoRow);
    await tester.pump();

    final text = tester.widget<Text>(
      find.descendant(of: huevoRow, matching: find.text('Huevo de codorniz')),
    );
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

    // Tocineta no es ingrediente propio del Cachorro → adicional
    // +$4.000; con stepper (§045) el + de su fila agrega 1 porción.
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ExtraStepperRow, 'Tocineta crocante'),
        matching: find.byIcon(Icons.add_rounded),
      ),
    );
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
    final rowFinder = find.ancestor(
      of: find.text('Tocineta crocante'),
      matching: find.byType(ExtraStepperRow),
    );
    final row = tester.widget<ExtraStepperRow>(rowFinder);
    expect(row.enabled, isFalse);

    // Stepper inerte (IgnorePointer) — el total no se mueve.
    await tester.tap(
      find.descendant(of: rowFinder, matching: find.byIcon(Icons.add_rounded)),
      warnIfMissed: false,
    );
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

  testWidgets(
    'CTA agrega al carrito con la personalización y vuelve a la carta',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // El toast es canal de plataforma — se captura para verificar
      // el mensaje de confirmación (§020).
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

      await pumpDetailWithRouter(tester, 'cachorro', _stateWith(_cachorro()));
      await tester.pumpAndSettle();

      // Un quitado + un adicional del fixture → 2 filas CartModifier.
      // §045: el quitado va por su RemovableRow ('Huevo de codorniz'
      // duplica con su fila de extra) y el extra por el + del stepper.
      await tester.tap(
        find.widgetWithText(RemovableRow, 'Huevo de codorniz'),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ExtraStepperRow, 'Tocineta crocante'),
          matching: find.byIcon(Icons.add_rounded),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Agregar al carrito'));
      await tester.pumpAndSettle();

      // El ítem llegó al cubit con los snapshots esperados.
      expect(cartCubit.state.items, hasLength(1));
      final item = cartCubit.state.items.single;
      expect(item.productId, 'p-cachorro');
      expect(item.productName, 'El Cachorro');
      expect(item.unitBase, 14000);
      expect(item.quantity, 1);
      expect(item.modifiers, [
        const CartModifier(
          optionId: 'o-huevo',
          optionName: 'Huevo de codorniz',
          action: CartModifierAction.removed,
          priceDelta: 0,
          group: CartModifierGroup.ingredient,
        ),
        const CartModifier(
          optionId: 'o-tocineta',
          optionName: 'Tocineta crocante',
          action: CartModifierAction.added,
          priceDelta: 4000,
          group: CartModifierGroup.extra,
        ),
      ]);
      expect(item.unitPrice, 18000);

      // Toast de éxito + pop a la carta (decisión del usuario §020).
      expect(calls, hasLength(1));
      expect(calls.first.arguments['msg'], 'Agregado al carrito');
      expect(find.text('CARTA'), findsOneWidget);
      expect(find.byType(ProductDetailScreen), findsNothing);

      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('slug desconocido → vista "no disponible" con salida', (
    tester,
  ) async {
    await pumpDetail(tester, 'inexistente', _stateWith(_cachorro()));
    await tester.pumpAndSettle();

    expect(find.text('Este producto ya no está en la carta'), findsOneWidget);
    expect(find.text('Volver al menú'), findsOneWidget);
  });

  testWidgets(
    'modo edición precarga los sets y el CTA dice "Guardar cambios"',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Ítem del carrito con un quitado, un extra cobrado, un
      // topping y una salsa — DetailSelections los reconstruye.
      const editing = CartItem(
        id: 'cart-9',
        productId: 'p-cachorro',
        productSlug: 'cachorro',
        productName: 'El Cachorro',
        unitBase: 14000,
        includedNames: ['Pan artesanal', 'Salchicha americana'],
        modifiers: [
          CartModifier(
            optionId: 'o-huevo',
            optionName: 'Huevo de codorniz',
            action: CartModifierAction.removed,
            priceDelta: 0,
          ),
          CartModifier(
            optionId: 'o-tocineta',
            optionName: 'Tocineta crocante',
            action: CartModifierAction.added,
            priceDelta: 4000,
          ),
          CartModifier(
            optionId: 'o-ripio',
            optionName: 'Papa ripio',
            action: CartModifierAction.added,
            priceDelta: 0,
          ),
          CartModifier(
            optionId: 'o-ketchup',
            optionName: 'Ketchup',
            action: CartModifierAction.added,
            priceDelta: 0,
          ),
        ],
      );

      await pumpDetail(
        tester,
        'cachorro',
        _stateWith(_cachorro()),
        editingItem: editing,
      );
      await tester.pumpAndSettle();

      // CTA del modo edición (§021) — nada de "Agregar al carrito".
      expect(find.text('Guardar cambios'), findsOneWidget);
      expect(find.text('Agregar al carrito'), findsNothing);
      // Cue de orientación: el título naciente anuncia la edición.
      expect(find.text('Editando · El Cachorro'), findsOneWidget);

      // Quitado precargado → la fila del huevo arranca tachada.
      // §045: 'Huevo de codorniz' duplica con su fila de extra — la
      // tachada es la de la RemovableRow.
      final huevoRow = find.widgetWithText(RemovableRow, 'Huevo de codorniz');
      final huevo = tester.widget<Text>(
        find.descendant(of: huevoRow, matching: find.text('Huevo de codorniz')),
      );
      expect(huevo.style?.decoration, TextDecoration.lineThrough);

      // Extra precargado → stepper en 1 porción + total con su
      // +$4.000 (14.000 + 4.000).
      final tocineta = tester.widget<ExtraStepperRow>(
        find.ancestor(
          of: find.text('Tocineta crocante'),
          matching: find.byType(ExtraStepperRow),
        ),
      );
      expect(tocineta.times, 1);
      expect(find.text(r'$18.000'), findsOneWidget);

      // Chips precargados — las secciones de abajo son lazy.
      await tester.scrollUntilVisible(find.text('Salsas'), 200);
      final ripio = tester.widget<SelectChip>(
        find.ancestor(
          of: find.text('Papa ripio'),
          matching: find.byType(SelectChip),
        ),
      );
      final ketchup = tester.widget<SelectChip>(
        find.ancestor(
          of: find.text('Ketchup'),
          matching: find.byType(SelectChip),
        ),
      );
      expect(ripio.selected, isTrue);
      expect(ketchup.selected, isTrue);
    },
  );

  testWidgets('guardar con qty 1 llama editItem y hace pop', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // El toast es canal de plataforma — se captura para verificar el
    // mensaje "Cambios guardados" (§021).
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

    // La fila editada ya vive en el cubit (id cart-1, qty 1 — sin
    // sheet de alcance).
    cartCubit.addItem(
      productId: 'p-cachorro',
      productSlug: 'cachorro',
      productName: 'El Cachorro',
      unitBase: 14000,
      modifiers: const [
        CartModifier(
          optionId: 'o-huevo',
          optionName: 'Huevo de codorniz',
          action: CartModifierAction.removed,
          priceDelta: 0,
        ),
      ],
      includedNames: const ['Pan artesanal', 'Salchicha americana'],
    );
    final editing = cartCubit.state.items.single;

    await pumpDetailWithRouter(
      tester,
      'cachorro',
      _stateWith(_cachorro()),
      editingItem: editing,
    );
    await tester.pumpAndSettle();

    // Edición real: se devuelve el huevo (RemovableRow — §045 el
    // texto duplica con su fila de extra) y se agrega tocineta por
    // el + de su stepper.
    await tester.tap(find.widgetWithText(RemovableRow, 'Huevo de codorniz'));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ExtraStepperRow, 'Tocineta crocante'),
        matching: find.byIcon(Icons.add_rounded),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    // editItem reemplazó la config de la fila — una sola queda.
    expect(cartCubit.state.items, hasLength(1));
    final item = cartCubit.state.items.single;
    expect(item.modifiers, [
      const CartModifier(
        optionId: 'o-tocineta',
        optionName: 'Tocineta crocante',
        action: CartModifierAction.added,
        priceDelta: 4000,
        group: CartModifierGroup.extra,
      ),
    ]);
    // El snapshot "Lleva:" se recapturó — el huevo volvió al perro.
    expect(item.includedNames, contains('Huevo de codorniz'));

    // Toast de edición + pop de vuelta.
    expect(calls, hasLength(1));
    expect(calls.first.arguments['msg'], 'Cambios guardados');
    expect(find.text('CARTA'), findsOneWidget);
    expect(find.byType(ProductDetailScreen), findsNothing);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
    'editar ítem con reemplazo no duplica la fila removed del agotado',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const channel = MethodChannel('PonnamKarthik/fluttertoast');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => true,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );

      // Ítem con par de reemplazo gratis: mozzarella agotada →
      // tocineta a $0 con replacesOptionId (§021).
      cartCubit.addItem(
        productId: 'p-cachorro',
        productSlug: 'cachorro',
        productName: 'El Cachorro',
        unitBase: 14000,
        modifiers: const [
          CartModifier(
            optionId: 'o-mozzarella',
            optionName: 'Queso mozzarella',
            action: CartModifierAction.removed,
            priceDelta: 0,
          ),
          CartModifier(
            optionId: 'o-tocineta',
            optionName: 'Tocineta crocante',
            action: CartModifierAction.added,
            priceDelta: 0,
            replacesOptionId: 'o-mozzarella',
          ),
        ],
        includedNames: const [
          'Pan artesanal',
          'Salchicha americana',
          'Huevo de codorniz',
        ],
      );
      final editing = cartCubit.state.items.single;

      await pumpDetailWithRouter(
        tester,
        'cachorro',
        _stateWith(_cachorro(mozzarellaAvailable: false)),
        editingItem: editing,
      );
      await tester.pumpAndSettle();

      // Un cambio real para que el guardado no sea no-op: quitar
      // el huevo (la regresión emitía el removed de mozzarella 2×).
      // §045: el texto duplica con la fila de extra → RemovableRow.
      await tester.tap(
        find.widgetWithText(RemovableRow, 'Huevo de codorniz'),
      );
      await tester.pump();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final mods = cartCubit.state.items.single.modifiers;
      expect(
        mods.where(
          (m) =>
              m.optionId == 'o-mozzarella' &&
              m.action == CartModifierAction.removed,
        ),
        hasLength(1),
      );
      expect(mods, hasLength(3)); // quita huevo + par del reemplazo
      expect(
        mods
            .singleWhere(
              (m) =>
                  m.optionId == 'o-tocineta' &&
                  m.action == CartModifierAction.added,
            )
            .replacesOptionId,
        'o-mozzarella',
      );

      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'producto agotado en modo edición → "Guardar cambios" sigue habilitado',
    (tester) async {
      const editing = CartItem(
        id: 'cart-9',
        productId: 'p-cachorro',
        productSlug: 'cachorro',
        productName: 'El Cachorro',
        unitBase: 14000,
        modifiers: [],
      );

      await pumpDetail(
        tester,
        'cachorro',
        _stateWith(_cachorro(productAvailable: false)),
        editingItem: editing,
      );
      await tester.pumpAndSettle();

      // El ítem ya vive en el carrito — el agotado no bloquea guardar
      // (la revalidación real es del backend al crear la orden).
      final cta = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar cambios'),
      );
      expect(cta.onPressed, isNotNull);
      expect(find.text('Agotado'), findsNothing);
    },
  );

  testWidgets(
    'guardar sin cambios con qty>1 → pop directo, sin sheet ni toast',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

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

      // qty 2 → normalmente preguntaría el alcance; sin cambios no.
      cartCubit
        ..addItem(
          productId: 'p-cachorro',
          productSlug: 'cachorro',
          productName: 'El Cachorro',
          unitBase: 14000,
          modifiers: const [
            CartModifier(
              optionId: 'o-huevo',
              optionName: 'Huevo de codorniz',
              action: CartModifierAction.removed,
              priceDelta: 0,
            ),
          ],
          includedNames: const ['Pan artesanal', 'Salchicha americana'],
        )
        ..addItem(
          productId: 'p-cachorro',
          productSlug: 'cachorro',
          productName: 'El Cachorro',
          unitBase: 14000,
          modifiers: const [
            CartModifier(
              optionId: 'o-huevo',
              optionName: 'Huevo de codorniz',
              action: CartModifierAction.removed,
              priceDelta: 0,
            ),
          ],
          includedNames: const ['Pan artesanal', 'Salchicha americana'],
        );
      final editing = cartCubit.state.items.single;
      expect(editing.quantity, 2);

      await pumpDetailWithRouter(
        tester,
        'cachorro',
        _stateWith(_cachorro()),
        editingItem: editing,
      );
      await tester.pumpAndSettle();

      // Label del footer: en edición con qty>1 el total es por unidad.
      expect(find.text('Total por unidad'), findsOneWidget);

      // Guardar sin tocar nada → misma config → vuelve sin preguntar.
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.text('¿A cuántos aplicar los cambios?'), findsNothing);
      expect(calls, isEmpty);
      expect(find.text('CARTA'), findsOneWidget);
      expect(find.byType(ProductDetailScreen), findsNothing);
      // La fila quedó intacta.
      expect(cartCubit.state.items.single.quantity, 2);
    },
  );

  testWidgets('back con cambios sin guardar → diálogo de descarte', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const editing = CartItem(
      id: 'cart-9',
      productId: 'p-cachorro',
      productSlug: 'cachorro',
      productName: 'El Cachorro',
      unitBase: 14000,
      modifiers: [],
    );

    await pumpDetailWithRouter(
      tester,
      'cachorro',
      _stateWith(_cachorro()),
      editingItem: editing,
    );
    await tester.pumpAndSettle();

    // Sin cambios el back sale directo — primero provocar uno.
    // §045: el texto duplica con la fila de extra → RemovableRow.
    await tester.tap(find.widgetWithText(RemovableRow, 'Huevo de codorniz'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    expect(find.text('Seguir editando'), findsOneWidget);
    expect(find.text('Descartar'), findsOneWidget);

    // "Seguir editando" cierra el diálogo y se queda en la pantalla.
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);

    // "Descartar" autoriza la salida — el pop se reintenta en el
    // frame donde el PopScope ya relee canPop.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('CARTA'), findsOneWidget);
    expect(find.byType(ProductDetailScreen), findsNothing);
  });
}
