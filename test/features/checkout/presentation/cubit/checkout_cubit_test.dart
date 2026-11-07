import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/auth/auth_session.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:depredadog_app/features/checkout/presentation/cubit/checkout_cubit.dart';
import 'package:depredadog_app/features/checkout/domain/entities/saved_address.dart';
import 'package:depredadog_app/features/checkout/presentation/cubit/checkout_state.dart';

const _userWithPhone = User(
  id: 'u-1',
  email: 'ana@correo.co',
  firstName: 'Ana',
  firstLastName: 'Pérez',
  phone: '3001234567',
  role: 'customer',
  status: 'active',
);

const _userNoPhone = User(
  id: 'u-2',
  email: 'luis@correo.co',
  firstName: 'Luis',
  firstLastName: 'Gómez',
  role: 'customer',
  status: 'active',
);

void main() {
  late CartCubit cartCubit;
  late AuthSession session;

  CheckoutCubit buildCubit({Duration delay = Duration.zero}) => CheckoutCubit(
    cartCubit: cartCubit,
    authSession: session,
    confirmDelay: delay,
  );

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
  });

  tearDown(() => cartCubit.close());

  group('estado inicial (§022)', () {
    test('pickup + Nequi + primera dirección + celular de la cuenta', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state.orderType, CheckoutOrderType.pickup);
      expect(cubit.state.paymentMethod, CheckoutPaymentMethod.nequi);
      expect(cubit.state.addressId, 'addr-casa');
      expect(cubit.state.nequiPhone, '3001234567');
      // §024 — el contacto de entrega prellena con el mismo phone.
      expect(cubit.state.contactPhone, '3001234567');
      expect(cubit.state.savedAddresses, hasLength(2));
      // Domicilio gratis (§022a) — el fee queda en 0.
      expect(cubit.state.store.deliveryFee, 0);
    });

    test('sesión sin phone → celular arranca vacío', () {
      session = AuthSession()..markAuthenticated(_userNoPhone);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state.nequiPhone, '');
      expect(cubit.state.contactPhone, '');
    });
  });

  group('totales (lee CartCubit, nunca lo muta)', () {
    test('pickup: total = subtotal (sin fee)', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.subtotal, 14000);
      expect(cubit.deliveryFee, 0);
      expect(cubit.total, 14000);
    });

    test('delivery: total = subtotal (domicilio gratis, §022a)', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.setOrderType(CheckoutOrderType.delivery);

      expect(cubit.deliveryFee, 0);
      expect(cubit.total, 14000);
      // El carrito queda intacto — la confirmación real lo vacía en
      // §015, no el cubit.
      expect(cartCubit.state.items, hasLength(1));
    });
  });

  group('pin de Google Maps del pedido (§022d, mock)', () {
    blocTest<CheckoutCubit, CheckoutState>(
      'adjuntar → link; quitar → null — es del pedido, no del form',
      build: buildCubit,
      act: (cubit) {
        cubit.attachDeliveryLocation();
        cubit.removeDeliveryLocation();
      },
      expect: () => [
        isA<CheckoutState>().having(
          (s) => s.deliveryLocationLink,
          'deliveryLocationLink',
          kCheckoutMockLocationLink,
        ),
        isA<CheckoutState>().having(
          (s) => s.deliveryLocationLink,
          'deliveryLocationLink',
          isNull,
        ),
      ],
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'el pin sobrevive a cambiar de dirección (order-level)',
      build: buildCubit,
      act: (cubit) {
        cubit.attachDeliveryLocation();
        cubit.selectAddress('addr-trabajo');
      },
      verify: (cubit) =>
          expect(cubit.state.deliveryLocationLink, kCheckoutMockLocationLink),
    );
  });

  group('toggle "Nueva ubicación" + tipo al guardar (§022b/d)', () {
    blocTest<CheckoutCubit, CheckoutState>(
      'segundo tap → colapsa el form pero la opción QUEDA marcada',
      build: buildCubit,
      act: (cubit) {
        cubit.toggleNewAddress();
        cubit.toggleNewAddress();
      },
      verify: (cubit) {
        expect(cubit.state.addressId, kCheckoutNewAddressId);
        expect(cubit.state.newAddressExpanded, isFalse);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'tercer tap → reabre el form; tocar guardada sí la desmarca',
      build: buildCubit,
      act: (cubit) {
        cubit.toggleNewAddress(); // selecciona + abre
        cubit.toggleNewAddress(); // colapsa, sigue marcada
        cubit.toggleNewAddress(); // reabre
      },
      verify: (cubit) {
        expect(cubit.state.addressId, kCheckoutNewAddressId);
        expect(cubit.state.newAddressExpanded, isTrue);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'confirm con form colapsado e incompleto → lo reabre con error',
      build: buildCubit,
      act: (cubit) async {
        cubit.setOrderType(CheckoutOrderType.delivery);
        cubit.toggleNewAddress(); // abre
        cubit.toggleNewAddress(); // colapsa vacío, sigue marcada
        await cubit.confirm();
      },
      verify: (cubit) {
        expect(cubit.state.showAddressError, isTrue);
        expect(cubit.state.newAddressExpanded, isTrue);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'el form conserva los campos al colapsar y reabrir',
      build: buildCubit,
      act: (cubit) {
        cubit.toggleNewAddress();
        cubit.newLandmarkChanged('Casa de teja al lado de la tienda');
        cubit.toggleNewAddress(); // colapsa
        cubit.toggleNewAddress(); // reabre
      },
      verify: (cubit) =>
          expect(cubit.state.newLandmark, 'Casa de teja al lado de la tienda'),
    );

    test('tipo arranca en casa + cambia a otro con nombre propio', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state.newAddressType, SavedAddressType.home);

      cubit.setNewAddressType(SavedAddressType.other);
      cubit.newAddressLabelChanged('Casa de mi mamá');

      expect(cubit.state.newAddressType, SavedAddressType.other);
      expect(cubit.state.newAddressLabel, 'Casa de mi mamá');
    });
  });

  group('validación al confirmar (§022 — inline, sin toast)', () {
    blocTest<CheckoutCubit, CheckoutState>(
      'delivery + nueva dirección vacía → showAddressError, no confirma',
      build: buildCubit,
      act: (cubit) async {
        cubit.setOrderType(CheckoutOrderType.delivery);
        cubit.toggleNewAddress();
        await cubit.confirm();
      },
      verify: (cubit) {
        expect(cubit.state.showAddressError, isTrue);
        expect(cubit.state.orderConfirmed, isFalse);
        expect(cubit.state.confirmInProgress, isFalse);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'solo punto de referencia (barrio opcional, §022a) → confirma',
      build: buildCubit,
      act: (cubit) async {
        cubit.setOrderType(CheckoutOrderType.delivery);
        cubit.toggleNewAddress();
        cubit.newLandmarkChanged('Casa blanca frente a la cancha');
        await cubit.confirm();
      },
      verify: (cubit) => expect(cubit.state.orderConfirmed, isTrue),
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'delivery + dirección guardada → confirma sin pedir más',
      build: buildCubit,
      act: (cubit) async {
        cubit.setOrderType(CheckoutOrderType.delivery);
        cubit.selectAddress('addr-trabajo');
        await cubit.confirm();
      },
      verify: (cubit) => expect(cubit.state.orderConfirmed, isTrue),
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'delivery + celular de contacto vacío → showContactPhoneError '
      '(§024)',
      build: buildCubit,
      act: (cubit) async {
        cubit.setOrderType(CheckoutOrderType.delivery);
        cubit.contactPhoneChanged('');
        await cubit.confirm();
      },
      verify: (cubit) {
        expect(cubit.state.showContactPhoneError, isTrue);
        expect(cubit.state.orderConfirmed, isFalse);
        expect(cubit.state.confirmInProgress, isFalse);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'celular de contacto que no es 3XXXXXXXXX → error (§024)',
      build: buildCubit,
      act: (cubit) async {
        cubit.setOrderType(CheckoutOrderType.delivery);
        cubit.contactPhoneChanged('12345');
        await cubit.confirm();
      },
      verify: (cubit) {
        expect(cubit.state.showContactPhoneError, isTrue);
        expect(cubit.state.orderConfirmed, isFalse);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'en pickup el contacto no se exige aunque esté vacío (§024)',
      build: buildCubit,
      act: (cubit) async {
        cubit.contactPhoneChanged('');
        await cubit.confirm();
      },
      verify: (cubit) {
        expect(cubit.state.showContactPhoneError, isFalse);
        expect(cubit.state.orderConfirmed, isTrue);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'Nequi con celular vacío → showNequiPhoneError',
      build: buildCubit,
      act: (cubit) async {
        cubit.nequiPhoneChanged('');
        await cubit.confirm();
      },
      verify: (cubit) {
        expect(cubit.state.showNequiPhoneError, isTrue);
        expect(cubit.state.orderConfirmed, isFalse);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'celular que no es 3XXXXXXXXX → error',
      build: buildCubit,
      act: (cubit) async {
        cubit.nequiPhoneChanged('12345');
        await cubit.confirm();
      },
      verify: (cubit) {
        expect(cubit.state.showNequiPhoneError, isTrue);
        expect(cubit.state.orderConfirmed, isFalse);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'domicilio con "al recibir" → volver a Local fuerza Nequi (§022c)',
      build: buildCubit,
      act: (cubit) {
        cubit.setOrderType(CheckoutOrderType.delivery);
        cubit.setPaymentMethod(CheckoutPaymentMethod.onDelivery);
        cubit.setOrderType(CheckoutOrderType.pickup);
      },
      verify: (cubit) =>
          expect(cubit.state.paymentMethod, CheckoutPaymentMethod.nequi),
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'pagar al recibir → el celular no se exige aunque esté vacío',
      build: buildCubit,
      act: (cubit) async {
        cubit.nequiPhoneChanged('');
        // "Al recibir" solo existe en domicilio (§022c).
        cubit.setOrderType(CheckoutOrderType.delivery);
        cubit.setPaymentMethod(CheckoutPaymentMethod.onDelivery);
        await cubit.confirm();
      },
      verify: (cubit) => expect(cubit.state.orderConfirmed, isTrue),
    );
  });

  group('confirmación (delay mock)', () {
    blocTest<CheckoutCubit, CheckoutState>(
      'válido → confirmInProgress → orderConfirmed',
      build: buildCubit,
      act: (cubit) => cubit.confirm(),
      expect: () => [
        isA<CheckoutState>().having(
          (s) => s.confirmInProgress,
          'confirmInProgress',
          isTrue,
        ),
        isA<CheckoutState>()
            .having((s) => s.confirmInProgress, 'confirmInProgress', isFalse)
            .having((s) => s.orderConfirmed, 'orderConfirmed', isTrue),
      ],
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'doble tap durante el delay no dispara dos confirmaciones',
      build: () => buildCubit(delay: const Duration(milliseconds: 800)),
      act: (cubit) async {
        unawaited(cubit.confirm());
        unawaited(cubit.confirm());
        await Future<void>.delayed(const Duration(seconds: 1));
      },
      verify: (cubit) => expect(cubit.state.orderConfirmed, isTrue),
      // Emisiones exactas: 2 (inProgress + confirmed) — sin duplicados.
      expect: () => [
        isA<CheckoutState>().having(
          (s) => s.confirmInProgress,
          'confirmInProgress',
          isTrue,
        ),
        isA<CheckoutState>().having(
          (s) => s.orderConfirmed,
          'orderConfirmed',
          isTrue,
        ),
      ],
    );
  });

  group('errores se limpian al editar', () {
    test('elegir dirección limpia showAddressError', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setOrderType(CheckoutOrderType.delivery);
      cubit.toggleNewAddress();
      cubit.confirm();
      expect(cubit.state.showAddressError, isTrue);

      cubit.selectAddress('addr-casa');
      expect(cubit.state.showAddressError, isFalse);
    });

    test('editar el celular limpia showNequiPhoneError', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.nequiPhoneChanged('12345');
      cubit.confirm();
      expect(cubit.state.showNequiPhoneError, isTrue);

      cubit.nequiPhoneChanged('3109876543');
      expect(cubit.state.showNequiPhoneError, isFalse);
    });

    test('editar el contacto limpia showContactPhoneError (§024)', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setOrderType(CheckoutOrderType.delivery);
      cubit.contactPhoneChanged('');
      cubit.confirm();
      expect(cubit.state.showContactPhoneError, isTrue);

      cubit.contactPhoneChanged('3109876543');
      expect(cubit.state.showContactPhoneError, isFalse);
    });

    test('volver a pickup limpia el error de dirección', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      cubit.setOrderType(CheckoutOrderType.delivery);
      cubit.toggleNewAddress();
      cubit.confirm();
      expect(cubit.state.showAddressError, isTrue);

      cubit.setOrderType(CheckoutOrderType.pickup);
      expect(cubit.state.showAddressError, isFalse);
    });
  });
}
