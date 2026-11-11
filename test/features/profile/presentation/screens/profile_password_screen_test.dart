import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/auth/presentation/widgets/custom_text_field.dart';
import 'package:depredadog_app/features/profile/presentation/screens/profile_password_screen.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  late GoRouter router;

  /// GoRouter mínimo (harness): /list stub + hija 'password' — el
  /// form es autónomo (sin cubit propio, §030.1).
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/list/password',
    routes: [
      GoRoute(
        path: '/list',
        builder: (_, _) => const Scaffold(body: Text('Lista')),
        routes: [
          GoRoute(
            path: 'password',
            builder: (_, _) => const ProfilePasswordScreen(),
          ),
        ],
      ),
    ],
  );

  setUp(() => router = buildRouter());
  tearDown(() => router.dispose());

  Future<void> pumpPassword(WidgetTester tester) => tester.pumpWidget(
    MaterialApp.router(
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
  );

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

  /// Los 3 campos en orden: actual, nueva, confirmar.
  Finder fieldAt(int i) => find.byType(TextFormField).at(i);

  /// El error inline del campo i — vive en el `errorText` del
  /// CustomTextField (el hint "Mínimo 8 caracteres" colisiona con el
  /// mensaje de error si se busca por texto — aserción exacta).
  String? errorAt(WidgetTester tester, int i) => tester
      .widget<CustomTextField>(find.byType(CustomTextField).at(i))
      .errorText;

  testWidgets('form: título + 3 campos obscure con toggle de '
      'visibilidad', (tester) async {
    await pumpPassword(tester);
    await tester.pumpAndSettle();

    // Título naciente + CTA comparten el copy — 2 instancias.
    expect(find.text('Cambiar contraseña'), findsNWidgets(2));
    expect(find.text('Contraseña actual *'), findsOneWidget);
    expect(find.text('Nueva contraseña *'), findsOneWidget);
    expect(find.text('Confirmar contraseña *'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    // Los 3 nacen ocultos con su ojo de toggle (obscureText vive en
    // el TextField interno del CustomTextField).
    for (var i = 0; i < 3; i++) {
      expect(
        tester.widget<TextField>(find.byType(TextField).at(i)).obscureText,
        isTrue,
      );
    }
    expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(3));
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    // Toggle del primero: deja de oscurecer y el ícono invierte.
    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).obscureText,
      isFalse,
    );
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));
  });

  testWidgets('guardar vacío → los 3 requeridos inline', (tester) async {
    await pumpPassword(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cambiar contraseña').last);
    await tester.pumpAndSettle();

    expect(errorAt(tester, 0), 'Ingresa tu contraseña actual');
    expect(errorAt(tester, 1), 'Ingresa una contraseña');
    expect(errorAt(tester, 2), 'Confirma tu contraseña');
    // Sigue en el form — no hay pop ni toast.
    expect(find.text('Contraseña actual *'), findsOneWidget);
  });

  testWidgets('nueva < 8 → "Mínimo 8 caracteres" (regla del '
      'registro/backend)', (tester) async {
    await pumpPassword(tester);
    await tester.pumpAndSettle();

    await tester.enterText(fieldAt(0), 'actual-ok');
    await tester.enterText(fieldAt(1), 'abc123');
    await tester.enterText(fieldAt(2), 'abc123');
    await tester.tap(find.text('Cambiar contraseña').last);
    await tester.pumpAndSettle();

    expect(errorAt(tester, 1), 'Mínimo 8 caracteres');
    // Solo la nueva falla — actual y confirmar quedan limpios.
    expect(errorAt(tester, 0), isNull);
    expect(errorAt(tester, 2), isNull);
    expect(find.text('Contraseña actual *'), findsOneWidget);
  });

  testWidgets('confirmar distinta → "Las contraseñas no coinciden"', (
    tester,
  ) async {
    await pumpPassword(tester);
    await tester.pumpAndSettle();

    await tester.enterText(fieldAt(0), 'actual-ok');
    await tester.enterText(fieldAt(1), 'nueva-segura-8');
    await tester.enterText(fieldAt(2), 'otra-distinta');
    await tester.tap(find.text('Cambiar contraseña').last);
    await tester.pumpAndSettle();

    expect(errorAt(tester, 2), 'Las contraseñas no coinciden');
  });

  testWidgets('guardar válido → toast "Contraseña actualizada" + pop', (
    tester,
  ) async {
    final toasts = stubToast(tester);
    await pumpPassword(tester);
    await tester.pumpAndSettle();

    await tester.enterText(fieldAt(0), 'actual-ok');
    await tester.enterText(fieldAt(1), 'nueva-segura-8');
    await tester.enterText(fieldAt(2), 'nueva-segura-8');
    await tester.tap(find.text('Cambiar contraseña').last);
    await tester.pumpAndSettle();

    expect(find.text('Lista'), findsOneWidget); // pop
    expect(toasts, hasLength(1));
    expect(toasts.single.method, 'showToast');
    expect(toasts.single.arguments['msg'], 'Contraseña actualizada');
    await tester.pump(const Duration(seconds: 2));
  });
}
