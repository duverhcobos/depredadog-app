import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/profile/presentation/widgets/profile_loyalty_card.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  /// Harness: la card sola dentro de un Scaffold — sin router ni
  /// cubits (recibe los datos por parámetro, §030.1).
  Future<void> pumpCard(
    WidgetTester tester, {
    String code = 'XK2P9QRD',
    int points = 120,
    int referredCount = 2,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: ListView(
          children: [
            ProfileLoyaltyCard(
              code: code,
              points: points,
              referredCount: referredCount,
            ),
          ],
        ),
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

  testWidgets('render: puntos + copy + código + referidos', (tester) async {
    await pumpCard(tester);
    await tester.pumpAndSettle();

    expect(find.text('120 puntos'), findsOneWidget);
    expect(find.text('Tu manada te premia'), findsOneWidget);
    expect(find.text('Tu código para la manada'), findsOneWidget);
    expect(find.text('XK2P9QRD'), findsOneWidget);
    expect(find.text('2 personas ya se sumaron con tu código'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('ícono info → diálogo puntos + referidos; Entendido cierra', (
    tester,
  ) async {
    await pumpCard(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text('¿Cómo funciona la manada?'), findsOneWidget);
    expect(find.textContaining('Acumulas puntos'), findsOneWidget);
    expect(find.textContaining('Comparte tu código'), findsOneWidget);

    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cómo funciona la manada?'), findsNothing);
  });

  testWidgets('plurales: 1 punto / 1 persona / nadie', (tester) async {
    await pumpCard(tester, points: 1, referredCount: 1);
    await tester.pumpAndSettle();
    expect(find.text('1 punto'), findsOneWidget);
    expect(find.text('1 persona ya se sumó con tu código'), findsOneWidget);

    await pumpCard(tester, points: 0, referredCount: 0);
    await tester.pumpAndSettle();
    expect(find.text('0 puntos'), findsOneWidget);
    expect(
      find.text('Nadie se ha sumado todavía con tu código'),
      findsOneWidget,
    );
  });

  testWidgets('copiar código → Clipboard.setData + toast', (tester) async {
    final toasts = stubToast(tester);
    final copied = stubClipboard(tester);
    await pumpCard(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.copy_rounded));
    await tester.pump();

    expect(copied, ['XK2P9QRD']);
    expect(toasts, hasLength(1));
    expect(toasts.single.method, 'showToast');
    expect(toasts.single.arguments['msg'], 'Código copiado');
    await tester.pump(const Duration(seconds: 2));
  });
}
