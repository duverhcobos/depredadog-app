import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:depredadog_app/core/auth/auth_session.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/profile/presentation/cubit/profile_addresses_cubit.dart';
import 'package:depredadog_app/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:depredadog_app/features/profile/presentation/cubit/profile_store_cubit.dart';
import 'package:depredadog_app/features/profile/presentation/screens/profile_addresses_screen.dart';
import 'package:depredadog_app/features/profile/presentation/screens/profile_data_screen.dart';
import 'package:depredadog_app/features/profile/presentation/screens/profile_password_screen.dart';
import 'package:depredadog_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:depredadog_app/features/profile/presentation/screens/profile_store_screen.dart';
import 'package:depredadog_app/features/profile/presentation/widgets/profile_menu_row.dart';
import 'package:depredadog_app/features/store/domain/entities/store_open_state.dart';
import 'package:depredadog_app/features/store/presentation/cubit/store_status_cubit.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

class MockStoreStatusCubit extends MockCubit<StoreOpenState>
    implements StoreStatusCubit {}

void main() {
  final locator = GetIt.instance;
  late ProfileCubit profileCubit;
  late ProfileAddressesCubit addressesCubit;
  late ProfileStoreCubit storeCubit;
  late MockStoreStatusCubit storeStatusCubit;
  late AuthSession authSession;
  late GoRouter router;

  const user = User(
    id: 'u1',
    email: 'test@depredadog.com',
    firstName: 'Test',
    firstLastName: 'User',
    role: 'customer',
    status: 'active',
  );

  /// GoRouter mínimo (harness): /profile con sus hijas reales de
  /// §030/§030.1 — igual que la branch de app_router.
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (_, _) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: 'addresses',
            builder: (_, _) => const ProfileAddressesScreen(),
          ),
          GoRoute(path: 'data', builder: (_, _) => const ProfileDataScreen()),
          GoRoute(path: 'store', builder: (_, _) => const ProfileStoreScreen()),
          GoRoute(
            path: 'password',
            builder: (_, _) => const ProfilePasswordScreen(),
          ),
        ],
      ),
    ],
  );

  setUp(() {
    profileCubit = ProfileCubit();
    addressesCubit = ProfileAddressesCubit();
    storeCubit = ProfileStoreCubit();
    storeStatusCubit = MockStoreStatusCubit();
    // §031 — la pantalla resuelve AuthSession y, solo en la rama
    // autenticada, ProfileCubit/ProfileAddressesCubit por locator.
    // Sesión marcada por default; el invitado sale con markLoggedOut().
    authSession = AuthSession()..markAuthenticated(user);
    locator.registerSingleton<AuthSession>(authSession);
    locator.registerSingleton<ProfileCubit>(profileCubit);
    locator.registerSingleton<ProfileAddressesCubit>(addressesCubit);
    // Chip del local abierto por defecto (§029 pattern — mock
    // MockCubit con estado stubbado, no hay refresh en tests).
    whenListen(
      storeStatusCubit,
      const Stream<StoreOpenState>.empty(),
      initialState: StoreOpenState.open,
    );
    router = buildRouter();
  });

  tearDown(() async {
    profileCubit.close();
    addressesCubit.close();
    storeCubit.close();
    storeStatusCubit.close();
    router.dispose();
    await locator.reset();
  });

  /// Harness: cubits reales (fase 1 son mocks sin dependencias) +
  /// MaterialApp.router con l10n y el tema oscuro fijo.
  Future<void> pumpProfile(WidgetTester tester) => tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ProfileCubit>.value(value: profileCubit),
        BlocProvider<ProfileAddressesCubit>.value(value: addressesCubit),
        BlocProvider<ProfileStoreCubit>.value(value: storeCubit),
        BlocProvider<StoreStatusCubit>.value(value: storeStatusCubit),
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

  /// Intercepta el canal de fluttertoast — AppToast no pinta en el
  /// árbol, va por MethodChannel (mismo patrón que
  /// app_shell_layout_test).
  List<MethodCall> stubToast(WidgetTester tester) {
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
    return calls;
  }

  /// Intercepta Clipboard.setData (SystemChannels.platform).
  List<String?> stubClipboard(WidgetTester tester) {
    final copied = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String?);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return copied;
  }

  /// Baja el ListView hasta que el finder aparezca (patrón de
  /// orders_screen_test — los hijos bajo el fold son lazy).
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('tab: identidad + loyalty card + filas del menú por '
      'sección', (tester) async {
    await pumpProfile(tester);
    await tester.pumpAndSettle();

    // Título naciente + card de identidad del mock.
    expect(find.text('PERFIL'), findsOneWidget);
    expect(find.text('Ana López'), findsOneWidget);
    expect(find.text('ana@test.com'), findsOneWidget);
    expect(find.text('300 123 4567'), findsOneWidget);
    expect(find.text('AL'), findsOneWidget); // iniciales del avatar

    // Loyalty card (§030.1): puntos + copy + código + referidos.
    expect(find.text('120 puntos'), findsOneWidget);
    expect(find.text('Tu manada te premia'), findsOneWidget);
    expect(find.text('Tu código para la manada'), findsOneWidget);
    expect(find.text('XK2P9QRD'), findsOneWidget);
    expect(find.text('2 personas ya se sumaron con tu código'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

    // Secciones + filas — las profundas se revelan con scroll (la
    // lista es lazy: los hijos fuera del viewport se desmontan).
    expect(find.text('Mi cuenta'), findsOneWidget);
    expect(find.text('Mis datos'), findsOneWidget);
    expect(find.text('Mis direcciones'), findsOneWidget);
    expect(find.text('3 guardadas'), findsOneWidget);
    await scrollTo(tester, find.text('Cambiar contraseña'));
    expect(find.text('Cambiar contraseña'), findsOneWidget);
    await scrollTo(tester, find.text('El negocio'));
    expect(find.text('El negocio'), findsOneWidget);
    expect(find.text('El local'), findsOneWidget);
    expect(find.text('Soporte'), findsOneWidget);
    // La destructiva es el ÚLTIMO ítem del scroll (decisión usuario
    // §030.1 — ya no está anclada).
    await scrollTo(tester, find.text('Cerrar sesión'));
    expect(find.text('Cerrar sesión'), findsOneWidget);

    // Chevron honesto: solo en las filas que navegan. Soporte abre
    // diálogo y la destructiva lo omite — verificado por descendiente
    // (la lista lazy descarta las filas de arriba al bajar).
    Finder rowOf(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byType(ProfileMenuRow),
    );
    expect(
      find.descendant(
        of: rowOf('El local'),
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: rowOf('Soporte'),
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: rowOf('Cerrar sesión'),
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsNothing,
    );
    // Es tab — sin flecha back.
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('el conteo "N guardadas" vive del cubit de la lista — '
      'borrar una dirección actualiza el subtítulo al volver', (tester) async {
    await pumpProfile(tester);
    await tester.pumpAndSettle();
    expect(find.text('3 guardadas'), findsOneWidget);

    addressesCubit.delete('a3');
    await tester.pumpAndSettle();
    expect(find.text('2 guardadas'), findsOneWidget);
  });

  testWidgets('copiar código de la loyalty card → Clipboard + AppToast '
      '"Código copiado"', (tester) async {
    final toasts = stubToast(tester);
    final copied = stubClipboard(tester);
    await pumpProfile(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.copy_rounded));
    await tester.pump();

    expect(copied, ['XK2P9QRD']);
    expect(toasts, hasLength(1));
    expect(toasts.single.method, 'showToast');
    expect(toasts.single.arguments['msg'], 'Código copiado');
    // Expira el Future.delayed interno de fluttertoast.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('"Mis datos" empuja /profile/data con el prefill del '
      'usuario', (tester) async {
    await pumpProfile(tester);
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Mis datos'));
    await tester.tap(find.text('Mis datos'));
    await tester.pumpAndSettle();

    expect(find.text('Mis datos'), findsOneWidget); // título naciente
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    // Prefill del mock — el TextFormField lleva el valor como
    // texto editable (find.text lo ve en el widget, no como Text).
    expect(find.text('ana@test.com'), findsOneWidget);
  });

  testWidgets('"El local" empuja /profile/store con nombre + chip real', (
    tester,
  ) async {
    await pumpProfile(tester);
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('El local'));
    await tester.tap(find.text('El local'));
    await tester.pumpAndSettle();

    expect(find.text('El local'), findsOneWidget); // título naciente
    expect(find.text('Depredadog'), findsOneWidget);
    expect(find.text('Abierto'), findsOneWidget); // chip real stub
    await scrollTo(tester, find.text('Domingo'));
    expect(find.text('Domingo'), findsOneWidget);
    expect(find.text('Cerrado'), findsOneWidget);
  });

  testWidgets('"Cambiar contraseña" empuja /profile/password', (tester) async {
    await pumpProfile(tester);
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Cambiar contraseña'));
    await tester.tap(find.text('Cambiar contraseña'));
    await tester.pumpAndSettle();

    // Título + CTA comparten el texto — ambos visibles.
    expect(find.text('Cambiar contraseña'), findsNWidgets(2));
    expect(find.text('Contraseña actual *'), findsOneWidget);
  });

  testWidgets('"Mis direcciones" empuja /profile/addresses', (tester) async {
    await pumpProfile(tester);
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Mis direcciones'));
    await tester.tap(find.text('Mis direcciones'));
    await tester.pumpAndSettle();

    // La hija conserva su propio título naciente y lista el mock.
    expect(find.text('Mis direcciones'), findsOneWidget);
    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('Trabajo'), findsOneWidget);
    expect(find.text('Mamá'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('"Soporte" abre el diálogo con el WhatsApp copiable', (
    tester,
  ) async {
    stubToast(tester);
    final copied = stubClipboard(tester);
    await pumpProfile(tester);
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Soporte'));
    await tester.tap(find.text('Soporte'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Escríbenos al WhatsApp del local:'), findsOneWidget);
    expect(find.text('+57 300 000 0000'), findsOneWidget);
    expect(find.text('Cerrar'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byIcon(Icons.copy_rounded),
      ),
    );
    await tester.pump();
    expect(copied, ['+57 300 000 0000']);
    // Expira el Future.delayed interno de fluttertoast — sin él el
    // test termina con un Timer pendiente.
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('"Cerrar sesión" → diálogo real; cancelar cierra sin '
      'tocar el cubit', (tester) async {
    await pumpProfile(tester);
    await tester.pumpAndSettle();

    // La destructiva es el último ítem del scroll — hay que bajar.
    await scrollTo(tester, find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    expect(
      find.text('Tendrás que iniciar sesión de nuevo para pedir.'),
      findsOneWidget,
    );
    expect(find.text('Cancelar'), findsOneWidget);
    // La acción destructiva dentro del diálogo.
    expect(find.text('Cerrar sesión'), findsNWidgets(2));

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    // Sigue en el tab al final del scroll, sin cambios de estado
    // (logout es stub §030 — el cubit conserva el usuario mock).
    expect(find.text('Soporte'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(profileCubit.state.user, isNotNull);
  });

  testWidgets('"Cerrar sesión" confirmado → toast cierra el loop '
      '(fase mock — revisor-ui)', (tester) async {
    // Intercepta el canal de fluttertoast — AppToast va por
    // MethodChannel, no pinta en el árbol.
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

    await pumpProfile(tester);
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    // La acción destructiva dentro del diálogo (la fila también
    // dice "Cerrar sesión" — la segunda es la del AlertDialog).
    await tester.tap(find.text('Cerrar sesión').last);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'showToast');
    expect(calls.single.arguments['msg'], 'Muy pronto podrás cerrar sesión');
    // fluttertoast agenda un timer interno de 1s — hay que dejarlo
    // disparar o el teardown falla con "timer pending".
    await tester.pump(const Duration(seconds: 1, milliseconds: 100));
  });

  group('invitado (§031 — wall card + "El negocio")', () {
    testWidgets('sin sesión: wall card + El negocio; sin identidad, '
        'Mi cuenta, loyalty ni logout', (tester) async {
      authSession.markLoggedOut();
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      expect(find.text('PERFIL'), findsOneWidget); // título conserva
      // El muro como CARD dentro del scroll (no pantalla de estado).
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(find.text('Inicia sesión para ver tu perfil'), findsOneWidget);
      expect(
        find.text('Tus datos, direcciones y puntos de la manada te esperan.'),
        findsOneWidget,
      );
      expect(find.text('Iniciar sesión'), findsOneWidget);
      // El TextButton es un Text.rich — textContaining mira el
      // contenido del TextSpan, find.text solo mira Text.data.
      expect(find.textContaining('Regístrate'), findsOneWidget);

      // "El negocio" con las 2 filas públicas de hoy.
      await scrollTo(tester, find.text('Soporte'));
      expect(find.text('El negocio'), findsOneWidget);
      expect(find.text('El local'), findsOneWidget);
      expect(find.text('Soporte'), findsOneWidget);

      // Lo que NO se muestra al invitado (decisión del usuario §031).
      expect(find.text('Ana López'), findsNothing);
      expect(find.text('Mi cuenta'), findsNothing);
      expect(find.text('Mis datos'), findsNothing);
      expect(find.text('120 puntos'), findsNothing);
      expect(find.text('Cerrar sesión'), findsNothing);
    });

    testWidgets('"El local" del invitado → /profile/store (ruta '
        'pública §031)', (tester) async {
      authSession.markLoggedOut();
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('El local'));
      await tester.tap(find.text('El local'));
      await tester.pumpAndSettle();

      // Push imperativo: el uri agregado del match list no lo refleja —
      // se mira la última pierna, igual que en el detalle de Pedidos.
      expect(
        router.routerDelegate.currentConfiguration.matches.last.matchedLocation,
        '/profile/store',
      );
      expect(find.text('Depredadog'), findsOneWidget);
      expect(find.text('Abierto'), findsOneWidget); // chip real stub
    });

    testWidgets('"Soporte" del invitado abre el mismo diálogo de hoy', (
      tester,
    ) async {
      stubToast(tester);
      authSession.markLoggedOut();
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('Soporte'));
      await tester.tap(find.text('Soporte'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('+57 300 000 0000'), findsOneWidget);

      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('el invitado ni siquiera resuelve los cubits de '
        'cliente (sin registro en el locator → no crash)', (tester) async {
      // Si la rama invitado tocara locator<ProfileCubit> esto
      // explotaría — el muro no necesita datos de cliente (§031).
      await locator.unregister<ProfileCubit>();
      await locator.unregister<ProfileAddressesCubit>();
      authSession.markLoggedOut();
      await pumpProfile(tester);
      await tester.pumpAndSettle();

      expect(find.text('Inicia sesión para ver tu perfil'), findsOneWidget);
      expect(find.text('El local'), findsOneWidget);
    });

    testWidgets('markAuthenticated con la página viva → swap '
        'muro→perfil sin navegar (ListenableBuilder)', (tester) async {
      authSession.markLoggedOut();
      await pumpProfile(tester);
      await tester.pumpAndSettle();
      expect(find.text('Inicia sesión para ver tu perfil'), findsOneWidget);

      // La sesión llega con el tab montado debajo del login — el
      // ChangeNotifier dispara el swap aunque go() no reconstruya.
      authSession.markAuthenticated(user);
      await tester.pumpAndSettle();

      expect(find.text('Inicia sesión para ver tu perfil'), findsNothing);
      expect(find.text('Ana López'), findsOneWidget);
      expect(find.text('Mi cuenta'), findsOneWidget);
    });
  });
}
