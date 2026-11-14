import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/admin/presentation/cubit/admin_queue_cubit.dart';
import 'package:depredadog_app/features/admin/presentation/screens/admin_history_screen.dart';
import 'package:depredadog_app/features/admin/presentation/widgets/admin_order_card.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

void main() {
  final locator = GetIt.instance;
  late AdminQueueCubit cubit;

  setUp(() {
    cubit = AdminQueueCubit();
    locator.registerSingleton<AdminQueueCubit>(cubit);
  });

  tearDown(() async {
    await cubit.close();
    await locator.reset();
  });

  /// El historial vive sobre el MISMO cubit de la cola — en prod lo
  /// envuelve el BlocProvider.value de la ruta /admin/history.
  Future<void> pumpHistory(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: BlocProvider.value(
        value: locator<AdminQueueCubit>(),
        child: const AdminHistoryScreen(),
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

  Future<void> loadQueue(WidgetTester tester) async {
    final load = cubit.load();
    await tester.pump(const Duration(milliseconds: 500));
    await load;
    await tester.pumpAndSettle();
  }

  testWidgets('historial provisional: cards de solo lectura, más '
      'reciente primero (§036)', (tester) async {
    await pumpHistory(tester);
    await loadQueue(tester);

    expect(find.text('Historial'), findsOneWidget);
    // Tres cancelados — incluidos el caso con motivo y el cobrado
    // (adm-18/19), las dos caras del archivo.
    expect(find.byType(AdminOrderCard), findsNWidgets(3));
    expect(find.text('En el local · Mesa 2'), findsOneWidget);
    expect(find.text('Karla Once'), findsOneWidget);
    expect(find.text('En el local · Mesa 8'), findsOneWidget);
    expect(find.text('Cancelado'), findsNWidgets(3));
    // Terminal = sin acción en la card.
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('historial vacío: empty con copy de marca', (tester) async {
    await cubit.close();
    await locator.reset();
    cubit = AdminQueueCubit(mockActive: const [], mockHistory: const []);
    locator.registerSingleton<AdminQueueCubit>(cubit);

    await pumpHistory(tester);
    await loadQueue(tester);

    expect(find.text('Historial vacío'), findsOneWidget);
    expect(
      find.text('Los pedidos terminados y cancelados quedan aquí.'),
      findsOneWidget,
    );
    expect(find.byType(AdminOrderCard), findsNothing);
  });
}
