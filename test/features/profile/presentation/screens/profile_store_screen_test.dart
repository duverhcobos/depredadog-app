import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/core/widgets/store_status_chip.dart';
import 'package:depredadog_app/features/profile/presentation/cubit/profile_store_cubit.dart';
import 'package:depredadog_app/features/profile/presentation/screens/profile_store_screen.dart';
import 'package:depredadog_app/features/store/domain/entities/store_open_state.dart';
import 'package:depredadog_app/features/store/presentation/cubit/store_status_cubit.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

class MockStoreStatusCubit extends MockCubit<StoreOpenState>
    implements StoreStatusCubit {}

void main() {
  late ProfileStoreCubit cubit;
  late MockStoreStatusCubit statusCubit;
  late GoRouter router;

  /// GoRouter mínimo (harness): /list stub + hija 'store' — como la
  /// de la branch profile en app_router (§030.1).
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/list/store',
    routes: [
      GoRoute(
        path: '/list',
        builder: (_, _) => const Scaffold(body: Text('Lista')),
        routes: [
          GoRoute(path: 'store', builder: (_, _) => const ProfileStoreScreen()),
        ],
      ),
    ],
  );

  void stubStatus(StoreOpenState state) => whenListen(
    statusCubit,
    const Stream<StoreOpenState>.empty(),
    initialState: state,
  );

  setUp(() {
    cubit = ProfileStoreCubit();
    statusCubit = MockStoreStatusCubit();
    stubStatus(StoreOpenState.open);
    router = buildRouter();
  });

  tearDown(() {
    cubit.close();
    statusCubit.close();
    router.dispose();
  });

  Future<void> pumpStore(WidgetTester tester) => tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ProfileStoreCubit>.value(value: cubit),
        BlocProvider<StoreStatusCubit>.value(value: statusCubit),
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

  testWidgets('card: nombre + chip abierto REAL + 7 días + '
      'dirección/teléfono', (tester) async {
    await pumpStore(tester);
    await tester.pumpAndSettle();

    expect(find.text('El local'), findsOneWidget); // título naciente
    expect(find.text('Depredadog'), findsOneWidget);
    // Chip del StoreStatusCubit — el widget real de la casa.
    final chip = tester.widget<StoreStatusChip>(find.byType(StoreStatusChip));
    expect(chip.isOpen, isTrue);
    expect(find.text('Abierto'), findsOneWidget);

    // Semana completa — la card es un solo hijo del ListView, las 7
    // filas viven dentro (no hay laziness interno).
    for (final day in [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ]) {
      expect(find.text(day), findsOneWidget);
    }
    expect(find.text('Horario'), findsOneWidget);
    // Lun–Jue 17:00–23:00, Vie–Sáb hasta 23:30, Dom cerrado —
    // display en 12h es-CO (convención de pedidos, revisor-ui §030.1).
    expect(find.text('5:00 p. m. – 11:00 p. m.'), findsNWidgets(4));
    expect(find.text('5:00 p. m. – 11:30 p. m.'), findsNWidgets(2));
    expect(find.text('Cerrado'), findsOneWidget); // solo domingo

    // Hoy resaltado: nombre del día en primary w700.
    final todayName = switch (DateTime.now().weekday % 7) {
      0 => 'Domingo',
      1 => 'Lunes',
      2 => 'Martes',
      3 => 'Miércoles',
      4 => 'Jueves',
      5 => 'Viernes',
      _ => 'Sábado',
    };
    final todayText = tester.widget<Text>(find.text(todayName));
    expect(todayText.style?.color, AppTheme.dark().colorScheme.primary);
    expect(todayText.style?.fontWeight, FontWeight.w700);
    // Y un día cualquiera que no sea hoy queda normal — el del
    // siguiente índice distinto al de hoy.
    final otherName = todayName == 'Lunes' ? 'Martes' : 'Lunes';
    expect(
      tester.widget<Text>(find.text(otherName)).style?.color,
      isNot(AppTheme.dark().colorScheme.primary),
    );

    // Filas de contacto: dirección + teléfono con máscara + copiar.
    expect(find.text('Calle 10 #4-35, frente a la plaza'), findsOneWidget);
    expect(find.text('300 765 4321'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('local cerrado → chip "Cerrado" del StoreStatusCubit', (
    tester,
  ) async {
    stubStatus(StoreOpenState.closed);
    await pumpStore(tester);
    await tester.pumpAndSettle();

    final chip = tester.widget<StoreStatusChip>(find.byType(StoreStatusChip));
    expect(chip.isOpen, isFalse);
    // "Cerrado" ×2: el chip + el domingo del horario.
    expect(find.text('Cerrado'), findsNWidgets(2));
  });

  testWidgets('estado unknown → sin chip (misma regla del header)', (
    tester,
  ) async {
    stubStatus(StoreOpenState.unknown);
    await pumpStore(tester);
    await tester.pumpAndSettle();

    expect(find.byType(StoreStatusChip), findsNothing);
    expect(find.text('Abierto'), findsNothing);
    // El resto de la card sigue — el horario no depende del status.
    expect(find.text('Depredadog'), findsOneWidget);
    expect(find.text('Domingo'), findsOneWidget);
  });

  testWidgets('copiar teléfono → Clipboard + toast "Número copiado"', (
    tester,
  ) async {
    final toasts = stubToast(tester);
    final copied = stubClipboard(tester);
    await pumpStore(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.copy_rounded));
    await tester.pump();

    expect(copied, ['3007654321']); // el raw, sin máscara
    expect(toasts, hasLength(1));
    expect(toasts.single.arguments['msg'], 'Número copiado');
    await tester.pump(const Duration(seconds: 2));
  });
}
