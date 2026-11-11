import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/checkout/domain/entities/saved_address.dart';
import 'package:depredadog_app/features/profile/presentation/cubit/profile_addresses_cubit.dart';
import 'package:depredadog_app/features/profile/presentation/screens/address_form_screen.dart';
import 'package:depredadog_app/features/profile/presentation/screens/profile_addresses_screen.dart';
import 'package:depredadog_app/features/profile/presentation/widgets/profile_address_tile.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  late ProfileAddressesCubit cubit;
  late GoRouter router;

  /// GoRouter mínimo (harness): /profile/addresses con hijas new +
  /// edit reales — igual que app_router (§030).
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/profile/addresses',
    routes: [
      GoRoute(
        path: '/profile/addresses',
        builder: (_, _) => const ProfileAddressesScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const AddressFormScreen()),
          GoRoute(
            path: 'edit',
            redirect: (_, state) =>
                state.extra is SavedAddress ? null : '/profile/addresses',
            builder: (_, state) =>
                AddressFormScreen(editing: state.extra! as SavedAddress),
          ),
        ],
      ),
      GoRoute(path: '/profile', builder: (_, _) => const SizedBox()),
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

  Future<void> pumpAddresses(WidgetTester tester) => tester.pumpWidget(
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

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  /// El ⋮ de una fila concreta — ubica el PopupMenuButton dentro del
  /// tile que contiene [label].
  Finder menuOf(String label) => find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(ProfileAddressTile),
    ),
    matching: find.byType(PopupMenuButton<String>),
  );

  testWidgets('lista: título + 3 tiles + badge solo en la default + '
      'CTA + back', (tester) async {
    await pumpAddresses(tester);
    await tester.pumpAndSettle();

    expect(find.text('Mis direcciones'), findsOneWidget);
    expect(find.byType(ProfileAddressTile), findsNWidgets(3));
    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('Trabajo'), findsOneWidget);
    expect(find.text('Mamá'), findsOneWidget);
    // Detalle: referencia · sector (solo cuando hay sector).
    expect(find.text('Casa blanca reja negra · Barrio Centro'), findsOneWidget);
    expect(find.text('Frente al parque'), findsOneWidget);
    // Una sola "Predeterminada" — en Casa (a1).
    expect(find.text('Predeterminada'), findsOneWidget);
    // Íconos por tipo + menús + CTA + flecha back (es hija, no tab).
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.work_outline), findsOneWidget);
    expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNWidgets(3));

    await scrollTo(tester, find.text('Nueva dirección'));
    expect(find.text('Nueva dirección'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('"Marcar predeterminada" mueve el badge con '
      'exclusividad; en la default queda deshabilitada', (tester) async {
    await pumpAddresses(tester);
    await tester.pumpAndSettle();

    // En Casa (default) la opción existe pero queda gris/inerte
    // (PopupMenuItem enabled:false — no dispara onSelected).
    await tester.tap(menuOf('Casa'));
    await tester.pumpAndSettle();
    final disabledItem = tester.widget<PopupMenuItem<String>>(
      find.ancestor(
        of: find.text('Marcar predeterminada'),
        matching: find.byType(PopupMenuItem<String>),
      ),
    );
    expect(disabledItem.enabled, isFalse);
    // Cierra el menú por la barrera — un ítem disabled no la descarta.
    await tester.tapAt(const Offset(300, 560));
    await tester.pumpAndSettle();
    expect(cubit.state.defaultAddress?.id, 'a1');

    // En Trabajo sí dispara: el badge migra y Casa lo pierde.
    await tester.tap(menuOf('Trabajo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar predeterminada'));
    await tester.pumpAndSettle();

    expect(cubit.state.defaultAddress?.id, 'a2');
    expect(find.text('Predeterminada'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Trabajo'),
          matching: find.byType(ProfileAddressTile),
        ),
        matching: find.text('Predeterminada'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('"Eliminar" → diálogo de confirmación real; confirma y '
      'la fila sale', (tester) async {
    await pumpAddresses(tester);
    await tester.pumpAndSettle();

    await tester.tap(menuOf('Trabajo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('¿Eliminar esta dirección?'), findsOneWidget);
    expect(
      find.text('La quitarás de tus direcciones guardadas.'),
      findsOneWidget,
    );
    expect(find.text('Cancelar'), findsOneWidget);
    // El "Eliminar" visible es SOLO la acción del diálogo — el item
    // del popup desapareció al cerrarse el menú.
    expect(find.text('Eliminar'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Eliminar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trabajo'), findsNothing);
    expect(find.byType(ProfileAddressTile), findsNWidgets(2));
    expect(cubit.state.addresses.map((a) => a.id), ['a1', 'a3']);
  });

  testWidgets('cancelar el diálogo de borrado conserva la fila', (
    tester,
  ) async {
    await pumpAddresses(tester);
    await tester.pumpAndSettle();

    await tester.tap(menuOf('Mamá'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Mamá'), findsOneWidget);
    expect(cubit.state.addresses, hasLength(3));
  });

  testWidgets('CTA "Nueva dirección" empuja al form de creación', (
    tester,
  ) async {
    await pumpAddresses(tester);
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Nueva dirección'));
    await tester.tap(find.text('Nueva dirección'));
    await tester.pumpAndSettle();

    // El form comparte el MISMO cubit — al guardar se ve en la lista.
    expect(find.text('Nueva dirección'), findsOneWidget);
    expect(find.text('Punto de referencia'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
  });

  testWidgets('tap en una fila → form en modo edición con prefill', (
    tester,
  ) async {
    await pumpAddresses(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trabajo'));
    await tester.pumpAndSettle();

    expect(find.text('Editar dirección'), findsOneWidget);
    expect(find.text('Oficina 201, edificio azul'), findsOneWidget);
  });

  testWidgets('borrar las 3 → estado vacío con ícono + copy + CTA', (
    tester,
  ) async {
    await pumpAddresses(tester);
    await tester.pumpAndSettle();

    cubit
      ..delete('a1')
      ..delete('a2')
      ..delete('a3');
    await tester.pumpAndSettle();

    expect(find.text('Sin direcciones guardadas'), findsOneWidget);
    expect(
      find.text('La próxima vez que pidas a domicilio puedes guardar una.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.location_off_outlined), findsOneWidget);
    expect(find.byType(ProfileAddressTile), findsNothing);
    // La creación sigue alcanzable desde el vacío (misma familia del
    // carrito vacío: ícono + copy + CTA).
    expect(find.text('Nueva dirección'), findsOneWidget);
    // Título vivo también en vacío.
    expect(find.text('Mis direcciones'), findsOneWidget);
  });
}
