import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:depredadog_app/features/profile/presentation/screens/profile_data_screen.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  late ProfileCubit cubit;
  late GoRouter router;

  /// GoRouter mínimo (harness): /list stub + hija 'data' — como la de
  /// la branch profile en app_router (§030.1).
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/list/data',
    routes: [
      GoRoute(
        path: '/list',
        builder: (_, _) => const Scaffold(body: Text('Lista')),
        routes: [
          GoRoute(path: 'data', builder: (_, _) => const ProfileDataScreen()),
        ],
      ),
    ],
  );

  setUp(() {
    cubit = ProfileCubit();
    router = buildRouter();
  });

  tearDown(() {
    cubit.close();
    router.dispose();
  });

  Future<void> pumpData(WidgetTester tester) => tester.pumpWidget(
    BlocProvider<ProfileCubit>.value(
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

  /// Intercepta el canal de fluttertoast — AppToast va por
  /// MethodChannel, no pinta en el árbol.
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

  /// Los 6 campos en orden: firstName, secondName, firstLastName,
  /// secondLastName, phone, email.
  Finder fieldAt(int i) => find.byType(TextFormField).at(i);

  testWidgets('form: título + prefill del mock + email read-only con '
      'helper', (tester) async {
    await pumpData(tester);
    await tester.pumpAndSettle();

    expect(find.text('Mis datos'), findsOneWidget); // título naciente
    // Labels — los mismos del registro (consistencia LatAm).
    expect(find.text('Primer nombre *'), findsOneWidget);
    expect(find.text('Segundo nombre (opcional)'), findsOneWidget);
    expect(find.text('Primer apellido *'), findsOneWidget);
    expect(find.text('Segundo apellido (opcional)'), findsOneWidget);
    expect(find.text('Teléfono (opcional)'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    // Prefill del usuario mock (find.text también lee EditableText).
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('López'), findsOneWidget);
    expect(find.text('3001234567'), findsOneWidget);
    expect(find.text('ana@test.com'), findsOneWidget);
    // Email: campo deshabilitado + helper que explica el bloqueo.
    expect(tester.widget<TextFormField>(fieldAt(5)).enabled, isFalse);
    expect(find.text('El correo no se puede cambiar'), findsOneWidget);

    expect(find.text('Guardar'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('guardar con requeridos vacíos → errores inline + nada '
      'llega al cubit', (tester) async {
    await pumpData(tester);
    await tester.pumpAndSettle();

    await tester.enterText(fieldAt(0), ''); // firstName
    await tester.enterText(fieldAt(2), ''); // firstLastName
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu nombre'), findsOneWidget);
    expect(find.text('Ingresa tu apellido'), findsOneWidget);
    // Sin mutación — la pantalla sigue abierta.
    expect(cubit.state.user, kMockProfileUser);
    expect(find.text('Guardar'), findsOneWidget);
  });

  testWidgets('teléfono mal formado → error accionable inline', (tester) async {
    await pumpData(tester);
    await tester.pumpAndSettle();

    // El campo limita a dígitos y 10 chars — "123" queda corto.
    await tester.enterText(fieldAt(4), '123');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Celular de 10 dígitos que inicia en 3'), findsOneWidget);
    expect(cubit.state.user, kMockProfileUser);
  });

  testWidgets('guardar válido → updateUser + toast + pop a la lista', (
    tester,
  ) async {
    final toasts = stubToast(tester);
    await pumpData(tester);
    await tester.pumpAndSettle();

    await tester.enterText(fieldAt(0), 'Ana María');
    await tester.enterText(fieldAt(1), 'José');
    await tester.enterText(fieldAt(3), 'Ruiz');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Volvió a la lista — el updateUser escribió sobre el cubit.
    expect(find.text('Lista'), findsOneWidget);
    final user = cubit.state.user!;
    expect(user.firstName, 'Ana María');
    expect(user.secondName, 'José');
    expect(user.firstLastName, 'López');
    expect(user.secondLastName, 'Ruiz');
    expect(user.phone, '3001234567');
    // Identidad intacta — el form no la toca.
    expect(user.id, 'mock-u1');
    expect(user.email, 'ana@test.com');
    expect(user.role, 'customer');

    expect(toasts, hasLength(1));
    expect(toasts.single.method, 'showToast');
    expect(toasts.single.arguments['msg'], 'Datos actualizados');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('campos opcionales vacíos → null en el User guardado', (
    tester,
  ) async {
    stubToast(tester);
    await pumpData(tester);
    await tester.pumpAndSettle();

    await tester.enterText(fieldAt(4), ''); // teléfono → null
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final user = cubit.state.user!;
    expect(user.phone, isNull);
    expect(user.secondName, isNull); // ya venía null
    await tester.pump(const Duration(seconds: 2));
  });
}
