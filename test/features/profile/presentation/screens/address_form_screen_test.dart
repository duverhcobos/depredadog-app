import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/checkout/domain/entities/saved_address.dart';
import 'package:depredadog_app/features/home/presentation/widgets/customization_section.dart';
import 'package:depredadog_app/features/profile/presentation/cubit/profile_addresses_cubit.dart';
import 'package:depredadog_app/features/profile/presentation/screens/address_form_screen.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  late ProfileAddressesCubit cubit;
  late GoRouter router;

  /// GoRouter mínimo (harness): /list stub con hijas new/edit —
  /// como las de la branch profile en app_router (§030).
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/list',
    routes: [
      GoRoute(
        path: '/list',
        builder: (_, _) => const Scaffold(body: Text('Lista')),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, _) => const AddressFormScreen(),
          ),
          GoRoute(
            path: 'edit',
            builder: (_, state) =>
                AddressFormScreen(editing: state.extra! as SavedAddress),
          ),
        ],
      ),
    ],
  );

  setUp(() {
    cubit = ProfileAddressesCubit();
    router = buildRouter();
  });

  tearDown(() {
    cubit.close();
    router.dispose();
  });

  Future<void> pumpForm(WidgetTester tester) => tester.pumpWidget(
    BlocProvider<ProfileAddressesCubit>.value(
      value: cubit,
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

  /// El SelectChip por su texto — los chips comparten familia con el
  /// checkout (customization_section).
  SelectChip chipOf(WidgetTester tester, String label) =>
      tester.widget<SelectChip>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(SelectChip),
        ),
      );

  testWidgets('crear: título "Nueva dirección" + chips + campos; '
      '"Otro" revela el nombre propio', (tester) async {
    await pumpForm(tester);
    router.push('/list/new');
    await tester.pumpAndSettle();

    expect(find.text('Nueva dirección'), findsOneWidget);
    expect(find.text('¿Qué lugar es?'), findsOneWidget);
    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('Trabajo'), findsOneWidget);
    expect(find.text('Otro'), findsOneWidget);
    // Casa seleccionada por defecto; el nombre propio NO existe
    // (reveal animado — SizedBox.shrink mientras no es "Otro").
    expect(chipOf(tester, 'Casa').selected, isTrue);
    expect(find.text('Nombre de la dirección'), findsNothing);
    // 2 campos visibles: referencia + barrio.
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Punto de referencia'), findsOneWidget);
    expect(find.text('Barrio o sector (opcional)'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    await tester.tap(find.text('Otro'));
    await tester.pumpAndSettle();
    expect(chipOf(tester, 'Otro').selected, isTrue);
    expect(find.text('Nombre de la dirección'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
  });

  testWidgets('guardar vacío → errores inline; "Otro" además exige '
      'nombre', (tester) async {
    await pumpForm(tester);
    router.push('/list/new');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Cuéntanos el punto de referencia'),
      findsOneWidget,
    );
    // Casa no pide nombre — sin error de label.
    expect(find.text('Ponle un nombre'), findsNothing);

    await tester.tap(find.text('Otro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ponle un nombre'), findsOneWidget);
    // Nada llegó al cubit — la pantalla sigue abierta.
    expect(cubit.state.addresses, hasLength(3));
    expect(find.text('Guardar'), findsOneWidget);
  });

  testWidgets('crear Casa → upsert con label del chip + pop a la '
      'lista', (tester) async {
    await pumpForm(tester);
    router.push('/list/new');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'Casa verde frente a la cancha',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // El upsert escribe sobre el cubit de la lista (singleton
    // compartido de la branch) y vuelve.
    expect(find.text('Lista'), findsOneWidget);
    expect(cubit.state.addresses, hasLength(4));
    final nueva = cubit.state.addresses.last;
    expect(nueva.label, 'Casa');
    expect(nueva.landmark, 'Casa verde frente a la cancha');
    expect(nueva.type, SavedAddressType.home);
    // No es la primera — NO nace default (a1 conserva el flag).
    expect(nueva.isDefault, isFalse);
    expect(cubit.state.defaultAddress?.id, 'a1');
  });

  testWidgets('crear "Otro" → el label viaja como lo escribió el '
      'usuario', (tester) async {
    await pumpForm(tester);
    router.push('/list/new');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Otro'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Portón gris al lado de la tienda',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'Novia');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(cubit.state.addresses, hasLength(4));
    final nueva = cubit.state.addresses.last;
    expect(nueva.label, 'Novia');
    expect(nueva.type, SavedAddressType.other);
  });

  testWidgets('primera dirección de la lista → nace default (regla '
      'del backend reflejada en fase 1)', (tester) async {
    cubit
      ..delete('a1')
      ..delete('a2')
      ..delete('a3');
    await pumpForm(tester);
    router.push('/list/new');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'Frente al parque',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(cubit.state.addresses, hasLength(1));
    expect(cubit.state.addresses.single.isDefault, isTrue);
  });

  testWidgets('editar: prefill + título; guardar reemplaza EN '
      'posición y conserva isDefault', (tester) async {
    final a2 = kMockAddresses[1]; // Trabajo, no default.
    await pumpForm(tester);
    router.push('/list/edit', extra: a2);
    await tester.pumpAndSettle();

    expect(find.text('Editar dirección'), findsOneWidget);
    // Prefill: referencia, barrio y chip del tipo guardado.
    expect(find.text('Oficina 201, edificio azul'), findsOneWidget);
    expect(find.text('Pueblo Nuevo'), findsOneWidget);
    expect(chipOf(tester, 'Trabajo').selected, isTrue);
    // Tipo work → el nombre propio queda oculto.
    expect(find.text('Nombre de la dirección'), findsNothing);

    await tester.enterText(
      find.byType(TextFormField).first,
      'Oficina 305, edificio azul',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Lista'), findsOneWidget);
    expect(cubit.state.addresses, hasLength(3));
    final editada = cubit.state.addresses[1];
    expect(editada.id, 'a2');
    expect(editada.landmark, 'Oficina 305, edificio azul');
    expect(editada.isDefault, isFalse);
    expect(cubit.state.defaultAddress?.id, 'a1');
  });
}
