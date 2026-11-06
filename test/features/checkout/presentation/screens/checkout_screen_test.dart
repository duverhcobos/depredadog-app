import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:depredadog_app/core/auth/auth_session.dart';
import 'package:depredadog_app/core/theme/app_theme.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:depredadog_app/features/checkout/domain/entities/saved_address.dart';
import 'package:depredadog_app/features/checkout/presentation/cubit/checkout_cubit.dart';
import 'package:depredadog_app/features/checkout/presentation/cubit/checkout_state.dart';
import 'package:depredadog_app/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:depredadog_app/features/home/presentation/widgets/customization_section.dart';
import 'package:depredadog_app/l10n/app_localizations.dart';

const _userWithPhone = User(
  id: 'u-1',
  email: 'ana@correo.co',
  firstName: 'Ana',
  firstLastName: 'Pérez',
  phone: '3001234567',
  role: 'customer',
  status: 'active',
);

void main() {
  late CartCubit cartCubit;
  late AuthSession session;
  late CheckoutCubit checkoutCubit;
  late GoRouter router;

  setUp(() {
    cartCubit = CartCubit()
      ..addItem(
        productId: 'p-cachorro',
        productSlug: 'cachorro',
        productName: 'El Cachorro',
        unitBase: 14000,
        modifiers: const [],
      );
    session = AuthSession()..markAuthenticated(_userWithPhone);
    // confirmDelay cero: la pantalla llega al diálogo en el mismo pump.
    checkoutCubit = CheckoutCubit(
      cartCubit: cartCubit,
      authSession: session,
      confirmDelay: Duration.zero,
    );
    // GoRouter mínimo (harness): /home/cart/checkout como ruta hija
    // real — el back-arrow tiene stack que pop y la confirmación
    // navega a /orders.
    router = GoRouter(
      initialLocation: '/home/cart/checkout',
      routes: [
        GoRoute(
          path: '/home/cart',
          builder: (_, _) => const Scaffold(body: Text('Carrito')),
          routes: [
            GoRoute(
              path: 'checkout',
              builder: (_, _) => const CheckoutScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/orders',
          builder: (_, _) => const Scaffold(body: Text('Pedidos')),
        ),
      ],
    );
  });

  tearDown(() {
    checkoutCubit.close();
    cartCubit.close();
    router.dispose();
  });

  /// Harness: cubits REALES (síncronos salvo el delay — más simple que
  /// mockear) + MaterialApp.router con l10n y el tema oscuro fijo.
  Future<void> pumpCheckout(WidgetTester tester) => tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<CartCubit>.value(value: cartCubit),
        BlocProvider<CheckoutCubit>.value(value: checkoutCubit),
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

  /// Baja el ListView hasta que el finder aparezca — las secciones
  /// bajo el fold no están construidas (lazy) y find.text no las ve.
  /// `delta` negativo sube (targets que quedaron sobre el viewport).
  Future<void> scrollTo(
    WidgetTester tester,
    Finder finder, {
    double delta = 120,
  }) => tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );

  testWidgets('pickup por defecto: título, secciones, local y totales', (
    tester,
  ) async {
    await pumpCheckout(tester);
    await tester.pumpAndSettle();

    // Título naciente + CTA del footer llevan el mismo texto.
    expect(find.text('Confirmar pedido'), findsNWidgets(2));
    expect(find.text('Tipo de pedido'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Lo recoges en'), findsOneWidget);
    expect(
      find.text('Depredadog — Costado norte del parque principal'),
      findsOneWidget,
    );
    expect(find.text('Te avisamos cuando esté listo'), findsOneWidget);

    // Nequi: logo oficial SVG sobre tile blanco (§022a), SIN el
    // subtítulo genérico (decisión del usuario).
    await scrollTo(tester, find.text('Nequi'));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Te llega la notificación push'), findsNothing);

    // Resumen: línea de ítem + subtotal/total sin fee en pickup.
    await scrollTo(tester, find.text('Tu pedido'));
    await tester.pumpAndSettle();
    expect(find.text('1× El Cachorro'), findsOneWidget);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text(r'$14.000'), findsWidgets);
    // La fila del fee no existe en pickup ("Gratis" tampoco aparece —
    // solo la píldora del toggle dice Domicilio arriba).
    expect(find.text('Gratis'), findsNothing);
  });

  testWidgets('toggle a Domicilio: ubicaciones + aviso y fila Gratis', (
    tester,
  ) async {
    await pumpCheckout(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Domicilio'));
    await tester.pumpAndSettle();

    // El aviso "Domicilio gratis" se retiró (§022d — sobraba: el
    // resumen ya lo dice donde importa).
    expect(find.text('Domicilio gratis'), findsNothing);
    // Ubicaciones guardadas como puntos de referencia (§022a).
    expect(find.text('Casa'), findsOneWidget);
    expect(
      find.text('Casa blanca frente a la cancha · Vereda El Carmen'),
      findsOneWidget,
    );
    expect(find.text('Trabajo'), findsOneWidget);
    expect(
      find.text('Segundo local del puente hacia arriba · Centro'),
      findsOneWidget,
    );
    expect(find.text('Nueva ubicación'), findsOneWidget);

    // El label de pago contra entrega cambia por tipo (§022) — la
    // sección Pago quedó bajo el fold con el bloque más alto.
    await scrollTo(tester, find.text('Pagar al recibir tu pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Pagar al recibir tu pedido'), findsOneWidget);

    await scrollTo(tester, find.text('Tu pedido'));
    await tester.pumpAndSettle();
    // Fila del fee solo en delivery — el domicilio ES gratis y el
    // resumen lo dice (§022a).
    expect(find.text('Gratis'), findsOneWidget);
    expect(find.text(r'$14.000'), findsWidgets);
  });

  testWidgets('"Nueva ubicación" despliega el form + validación inline', (
    tester,
  ) async {
    await pumpCheckout(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Domicilio'));
    await tester.pumpAndSettle();

    // El pin es del PEDIDO (§022d): el botón vive en su división al
    // pie del bloque, disponible con la guardada marcada — no dentro
    // del form.
    await scrollTo(tester, find.text('Adjuntar ubicación de Google'));
    await tester.pumpAndSettle();
    expect(find.text('Adjuntar ubicación de Google'), findsOneWidget);

    // Adjuntar → estado adjunto con el link mock; quitar → vuelve el
    // botón.
    await tester.tap(find.text('Adjuntar ubicación de Google'));
    await tester.pumpAndSettle();
    expect(find.text('Ubicación adjunta'), findsOneWidget);
    expect(find.text('maps.app.goo.gl/xK9fP2AbCd3'), findsOneWidget);
    await tester.tap(find.byTooltip('Quitar ubicación'));
    await tester.pumpAndSettle();
    expect(find.text('Adjuntar ubicación de Google'), findsOneWidget);

    // La fila quedó sobre el fold tras el scroll al pin — subir.
    await scrollTo(tester, find.text('Nueva ubicación'), delta: -120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva ubicación'));
    await tester.pumpAndSettle();

    // Form por puntos de referencia (§022a): referencia*, barrio
    // opcional, guardar.
    expect(find.text('Punto de referencia *'), findsOneWidget);
    expect(find.text('Barrio o sector (opcional)'), findsOneWidget);
    expect(find.text('Guardar esta ubicación'), findsOneWidget);

    // Confirmar con el form incompleto → error inline en el único
    // requerido (§022a).
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido'));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Ingresa el punto de referencia'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa el punto de referencia'), findsOneWidget);
    // El diálogo de éxito NO aparece.
    expect(find.text('¡Pedido confirmado!'), findsNothing);
  });

  testWidgets(
    '"Nueva ubicación" colapsa SIN desmarcar + tipo al guardar (§022d)',
    (tester) async {
      await pumpCheckout(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Domicilio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva ubicación'));
      await tester.pumpAndSettle();

      // El selector de tipo NO existe aún — vive detrás del checkbox
      // "Guardar esta ubicación" (el nombre solo sirve al guardar).
      expect(find.text('¿Qué lugar es?'), findsNothing);

      await tester.tap(find.text('Guardar esta ubicación'));
      await tester.pumpAndSettle();
      expect(find.text('¿Qué lugar es?'), findsOneWidget);

      // "Otro" revela el campo del nombre propio y alimenta el cubit.
      final otroChip = find.widgetWithText(SelectChip, 'Otro');
      await scrollTo(tester, otroChip);
      await tester.pumpAndSettle();
      await tester.tap(otroChip);
      await tester.pumpAndSettle();
      expect(checkoutCubit.state.newAddressType, SavedAddressType.other);

      final nameField = find.widgetWithText(TextField, 'Ej: casa de mi mamá');
      await scrollTo(tester, nameField);
      await tester.pumpAndSettle();
      await tester.enterText(nameField, 'Casa de mi mamá');
      await tester.pumpAndSettle();
      expect(checkoutCubit.state.newAddressLabel, 'Casa de mi mamá');

      // Segundo tap en la fila → SOLO colapsa el form (§022d): la
      // opción queda MARCADA — desmarcar es tocar otra dirección. La
      // fila quedó sobre el fold tras el scroll al campo del nombre.
      await scrollTo(tester, find.text('Nueva ubicación'), delta: -120);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva ubicación'));
      await tester.pumpAndSettle();
      expect(find.text('Punto de referencia *'), findsNothing);
      expect(checkoutCubit.state.addressId, kCheckoutNewAddressId);
      expect(checkoutCubit.state.newAddressExpanded, isFalse);

      // Tercer tap → reabre conservando lo tipeado.
      await tester.tap(find.text('Nueva ubicación'));
      await tester.pumpAndSettle();
      expect(find.text('Punto de referencia *'), findsOneWidget);
      expect(checkoutCubit.state.newAddressLabel, 'Casa de mi mamá');
    },
  );

  testWidgets('celular Nequi solo visible con Nequi y viene prellenado', (
    tester,
  ) async {
    await pumpCheckout(tester);
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Celular Nequi'));
    await tester.pumpAndSettle();
    // Prefill del phone de la cuenta (decisión del usuario §022).
    expect(find.text('3001234567'), findsOneWidget);

    // En domicilio sí existe "Pagar al recibir tu pedido" (§022c) —
    // al cambiar a ella el campo desaparece.
    await scrollTo(tester, find.text('Domicilio'), delta: -120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Domicilio'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Pagar al recibir tu pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pagar al recibir tu pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Celular Nequi'), findsNothing);
    expect(find.text('3001234567'), findsNothing);
  });

  testWidgets(
    'Local: sin pago en efectivo — solo transferencia + nota (§022c)',
    (tester) async {
      await pumpCheckout(tester);
      await tester.pumpAndSettle();

      // Regla del negocio: en el local un pedido no recogido ya quedó
      // hecho y nunca se cobró — la fila contra entrega no existe y
      // la nota explica por qué solo hay Nequi.
      await scrollTo(tester, find.text('Nequi'));
      await tester.pumpAndSettle();
      expect(find.text('Pagar al recibir'), findsNothing);
      expect(find.text('Pagar al recibir tu pedido'), findsNothing);
      expect(
        find.text('En el local el pago es solo por transferencia'),
        findsOneWidget,
      );
      expect(checkoutCubit.state.paymentMethod, CheckoutPaymentMethod.nequi);

      // En domicilio la opción contra entrega vuelve a existir.
      await scrollTo(tester, find.text('Domicilio'), delta: -120);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Domicilio'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Pagar al recibir tu pedido'));
      await tester.pumpAndSettle();
      expect(find.text('Pagar al recibir tu pedido'), findsOneWidget);
      expect(
        find.text('En el local el pago es solo por transferencia'),
        findsNothing,
      );
    },
  );

  testWidgets('celular Nequi inválido → error inline al confirmar', (
    tester,
  ) async {
    await pumpCheckout(tester);
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Celular Nequi'));
    await tester.pumpAndSettle();
    // Único TextFormField visible en esta pantalla (los del form de
    // nueva dirección aún no existen — pickup + guardada).
    await tester.enterText(find.byType(TextFormField), '123');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido'));
    await tester.pumpAndSettle();

    expect(find.text('Celular incorrecto'), findsOneWidget);
    expect(find.text('¡Pedido confirmado!'), findsNothing);
  });

  testWidgets('confirmación válida → diálogo → vacía carrito y va a Pedidos', (
    tester,
  ) async {
    await pumpCheckout(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido'));
    await tester.pumpAndSettle();

    // Diálogo de éxito mock (§022 — flujo completo simulado).
    expect(find.text('¡Pedido confirmado!'), findsOneWidget);
    // §022b: el subtítulo del diálogo NO lleva número de orden — el
    // consecutivo revela el volumen de ventas (decisión del usuario).
    // 'Te avisamos...' también existe en el cuerpo pickup — se
    // verifica DENTRO del AlertDialog.
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Te avisamos cuando esté listo'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('#'),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Ver mis pedidos'));
    await tester.pumpAndSettle();

    // Carrito vacío + navegación a /orders (placeholder del test).
    expect(cartCubit.state.isEmpty, isTrue);
    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Confirmar pedido'), findsNothing);
  });

  testWidgets(
    'Observación: va bajo Tipo de pedido y alimenta el cubit (§022a)',
    (tester) async {
      await pumpCheckout(tester);
      await tester.pumpAndSettle();

      // Sección renombrada y reubicada — queda entre "Tipo de pedido"
      // y "Pago" (decisión del usuario §022a).
      expect(find.text('Observación'), findsOneWidget);
      expect(find.text('Nota para el local'), findsNothing);
      final tipoY = tester.getTopLeft(find.text('Tipo de pedido')).dy;
      final obsY = tester.getTopLeft(find.text('Observación')).dy;
      expect(obsY, greaterThan(tipoY));

      // "Pago" quedó DESPUÉS de Observación en el scroll — al traerla
      // a pantalla, Observación sigue arriba de ella.
      await scrollTo(tester, find.text('Pago'));
      await tester.pumpAndSettle();
      final pagoY = tester.getTopLeft(find.text('Pago')).dy;
      final obsY2 = tester.getTopLeft(find.text('Observación')).dy;
      expect(obsY2, lessThan(pagoY));

      // TextFormField internamente construye un TextField — el de la
      // observación se distingue por su hint (ejemplo acorde a la
      // zona: efectivo/cambio).
      final noteField = find.widgetWithText(
        TextField,
        '¿Algo que debamos saber? — p. ej. pago con billete de 50, '
        'traer cambio',
      );
      await scrollTo(tester, noteField);
      await tester.pumpAndSettle();

      await tester.enterText(noteField, 'Pago con billete de 50');
      await tester.pumpAndSettle();

      expect(checkoutCubit.state.note, 'Pago con billete de 50');
    },
  );
}
