import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/auth/auth_session.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/cart/domain/entities/cart_modifier.dart';
import 'package:depredadog_app/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:depredadog_app/features/checkout/domain/entities/checkout_store.dart';
import 'package:depredadog_app/features/checkout/domain/entities/placed_order.dart';
import 'package:depredadog_app/features/checkout/domain/entities/saved_address.dart';
import 'package:depredadog_app/features/checkout/domain/failures/checkout_failure.dart';
import 'package:depredadog_app/features/checkout/domain/use_cases/create_order_params.dart';
import 'package:depredadog_app/features/checkout/domain/use_cases/create_order_use_case.dart';
import 'package:depredadog_app/features/checkout/domain/use_cases/load_checkout_data_use_case.dart';
import 'package:depredadog_app/features/checkout/domain/use_cases/save_address_use_case.dart';
import 'package:depredadog_app/features/checkout/presentation/cubit/checkout_cubit.dart';
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

const _addresses = <SavedAddress>[
  SavedAddress(
    id: 'addr-casa',
    label: 'Casa',
    landmark: 'Casa blanca frente a la cancha',
    neighborhood: 'Vereda El Carmen',
    type: SavedAddressType.home,
  ),
  SavedAddress(
    id: 'addr-trabajo',
    label: 'Trabajo',
    landmark: 'Segundo local del puente hacia arriba',
    neighborhood: 'Centro',
    type: SavedAddressType.work,
  ),
];

const _storeOpen = CheckoutStore(
  name: 'Depredadog',
  address: 'Costado norte del parque principal',
  deliveryFee: 0,
);

const _storeClosed = CheckoutStore(
  name: 'Depredadog',
  address: 'Costado norte del parque principal',
  deliveryFee: 0,
  isOpen: false,
);

const _savedResponse = SavedAddress(
  id: 'addr-nueva',
  label: 'Casa',
  landmark: 'Casa de teja',
  type: SavedAddressType.home,
);

const _placed = PlacedOrder(
  id: 'o-1',
  orderNumber: 7,
  status: 'pending',
  total: 14000,
);

class MockLoadCheckoutData extends Mock implements LoadCheckoutDataUseCase {}

class MockSaveAddress extends Mock implements SaveAddressUseCase {}

class MockCreateOrder extends Mock implements CreateOrderUseCase {}

void main() {
  late CartCubit cartCubit;
  late AuthSession session;
  late MockLoadCheckoutData loadData;
  late MockSaveAddress saveAddress;
  late MockCreateOrder createOrder;
  late CheckoutDataResult loadResult;

  CheckoutCubit buildCubit({String clientRequestId = 'req-test'}) =>
      CheckoutCubit(
        cartCubit: cartCubit,
        authSession: session,
        loadCheckoutDataUseCase: loadData,
        saveAddressUseCase: saveAddress,
        createOrderUseCase: createOrder,
        clientRequestId: clientRequestId,
      );

  setUpAll(() {
    registerFallbackValue(SavedAddressType.home);
    registerFallbackValue(
      const CreateOrderParams(
        serviceType: 'pickup',
        paymentMethod: 'cash',
        items: [],
        clientRequestId: '',
      ),
    );
  });

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
    loadData = MockLoadCheckoutData();
    saveAddress = MockSaveAddress();
    createOrder = MockCreateOrder();
    loadResult = const CheckoutDataResult(
      addresses: Right(_addresses),
      store: Right(_storeOpen),
    );
    when(() => loadData.call()).thenAnswer((_) async => loadResult);
    when(
      () => saveAddress.call(
        label: any(named: 'label'),
        landmark: any(named: 'landmark'),
        neighborhood: any(named: 'neighborhood'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => const Right(_savedResponse));
    when(() => createOrder.call(any()))
        .thenAnswer((_) async => const Right(_placed));
  });

  tearDown(() => cartCubit.close());

  group('estado inicial (§025)', () {
    test('vacío + dataLoading + prefills de celular; addressId se '
        'resuelve al cargar', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state.orderType, CheckoutOrderType.pickup);
      expect(cubit.state.paymentMethod, CheckoutPaymentMethod.nequi);
      expect(cubit.state.dataLoading, isTrue);
      expect(cubit.state.savedAddresses, isEmpty);
      expect(cubit.state.addressId, isNull);
      expect(cubit.state.store.name, '');
      expect(cubit.state.nequiPhone, '3001234567');
      // §024 — el contacto de entrega prellena con el mismo phone.
      expect(cubit.state.contactPhone, '3001234567');
    });

    test('sesión sin phone → celular arranca vacío', () {
      session = AuthSession()..markAuthenticated(_userNoPhone);
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state.nequiPhone, '');
      expect(cubit.state.contactPhone, '');
    });
  });

  group('loadCheckoutData (§025)', () {
    blocTest<CheckoutCubit, CheckoutState>(
      'load ok → savedAddresses reales + prefill primera + store real',
      build: buildCubit,
      act: (cubit) => cubit.loadCheckoutData(),
      verify: (cubit) {
        expect(cubit.state.savedAddresses, hasLength(2));
        expect(cubit.state.addressId, 'addr-casa');
        expect(cubit.state.store.name, 'Depredadog');
        expect(cubit.state.store.isOpen, isTrue);
        expect(cubit.state.addressesFailed, isFalse);
        expect(cubit.state.storeFailed, isFalse);
        expect(cubit.state.dataLoading, isFalse);
      },
    );

    test('lista vacía (cliente nuevo) → new + form expandido', () async {
      loadResult = const CheckoutDataResult(
        addresses: Right(<SavedAddress>[]),
        store: Right(_storeOpen),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.loadCheckoutData();

      expect(cubit.state.savedAddresses, isEmpty);
      expect(cubit.state.addressId, kCheckoutNewAddressId);
      expect(cubit.state.newAddressExpanded, isTrue);
    });

    test('addresses fail → addressesFailed + fallback new (pickup no '
        'se bloquea)', () async {
      loadResult = const CheckoutDataResult(
        addresses: Left(CheckoutServerFailure('boom')),
        store: Right(_storeOpen),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.loadCheckoutData();

      expect(cubit.state.addressesFailed, isTrue);
      expect(cubit.state.savedAddresses, isEmpty);
      expect(cubit.state.addressId, kCheckoutNewAddressId);
      expect(cubit.state.store.name, 'Depredadog');
      expect(cubit.state.dataLoading, isFalse);
    });

    test('store fail → storeFailed + placeholder CERRADO (seguro) — '
        'las piernas degradan por separado', () async {
      loadResult = const CheckoutDataResult(
        addresses: Right(_addresses),
        store: Left(CheckoutServerFailure('boom')),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.loadCheckoutData();

      expect(cubit.state.storeFailed, isTrue);
      expect(cubit.state.store.isOpen, isFalse);
      expect(cubit.state.addressesFailed, isFalse);
      expect(cubit.state.addressId, 'addr-casa');
      expect(cubit.state.dataLoading, isFalse);
    });

    test('retry limpia los flags y recupera', () async {
      loadResult = const CheckoutDataResult(
        addresses: Left(CheckoutServerFailure('boom')),
        store: Left(CheckoutServerFailure('boom')),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.loadCheckoutData();
      expect(cubit.state.addressesFailed, isTrue);
      expect(cubit.state.storeFailed, isTrue);

      loadResult = const CheckoutDataResult(
        addresses: Right(_addresses),
        store: Right(_storeOpen),
      );
      await cubit.loadCheckoutData();
      expect(cubit.state.addressesFailed, isFalse);
      expect(cubit.state.storeFailed, isFalse);
      expect(cubit.state.savedAddresses, hasLength(2));
      expect(cubit.state.addressId, 'addr-casa');
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

    test('delivery: total = subtotal (domicilio gratis, §022a)', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();

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
      act: (cubit) async {
        await cubit.loadCheckoutData();
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
      act: (cubit) async {
        await cubit.loadCheckoutData();
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
      act: (cubit) async {
        await cubit.loadCheckoutData();
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
        await cubit.loadCheckoutData();
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
      act: (cubit) async {
        await cubit.loadCheckoutData();
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

    test('mientras dataLoading las selecciones son no-op (§025)', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.toggleNewAddress();
      expect(cubit.state.addressId, isNull);
      cubit.selectAddress('addr-casa');
      expect(cubit.state.addressId, isNull);
    });
  });

  group('validación al confirmar (§022 — inline, sin toast)', () {
    blocTest<CheckoutCubit, CheckoutState>(
      'delivery + nueva dirección vacía → showAddressError, no confirma',
      build: buildCubit,
      act: (cubit) async {
        await cubit.loadCheckoutData();
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
        await cubit.loadCheckoutData();
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
        await cubit.loadCheckoutData();
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
        await cubit.loadCheckoutData();
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
        await cubit.loadCheckoutData();
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
        await cubit.loadCheckoutData();
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
        await cubit.loadCheckoutData();
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
        await cubit.loadCheckoutData();
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
        await cubit.loadCheckoutData();
        cubit.nequiPhoneChanged('');
        // "Al recibir" solo existe en domicilio (§022c).
        cubit.setOrderType(CheckoutOrderType.delivery);
        cubit.setPaymentMethod(CheckoutPaymentMethod.onDelivery);
        await cubit.confirm();
      },
      verify: (cubit) => expect(cubit.state.orderConfirmed, isTrue),
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'local cerrado (isOpen=false) → confirm() no avanza (§025)',
      build: buildCubit,
      setUp: () {
        loadResult = const CheckoutDataResult(
          addresses: Right(_addresses),
          store: Right(_storeClosed),
        );
      },
      act: (cubit) async {
        await cubit.loadCheckoutData();
        await cubit.confirm();
      },
      verify: (cubit) {
        expect(cubit.state.orderConfirmed, isFalse);
        expect(cubit.state.confirmInProgress, isFalse);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'mientras dataLoading → confirm() no avanza (§025)',
      build: buildCubit,
      act: (cubit) => cubit.confirm(),
      verify: (cubit) {
        expect(cubit.state.orderConfirmed, isFalse);
        expect(cubit.state.confirmInProgress, isFalse);
      },
    );
  });

  group('guardar ubicación al confirmar (§025 — auxiliar, nunca '
      'aborta la compra)', () {
    test('save ok → savedAddresses gana la nueva + justSavedAddress; '
        'label casa = l10n del chip', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();
      cubit.setOrderType(CheckoutOrderType.delivery);
      cubit.toggleNewAddress();
      cubit.newLandmarkChanged('Casa de teja');
      cubit.toggleSaveNewAddress(); // tipo arranca en home → 'Casa'

      await cubit.confirm();

      verify(
        () => saveAddress.call(
          label: 'Casa',
          landmark: 'Casa de teja',
          type: SavedAddressType.home,
        ),
      ).called(1);
      expect(cubit.state.savedAddresses.last.id, 'addr-nueva');
      expect(cubit.state.justSavedAddress?.id, 'addr-nueva');
      expect(cubit.state.orderConfirmed, isTrue);
      expect(cubit.state.addressSaveFailed, isFalse);
    });

    test('tipo otro → label = nombre propio; neighborhood viaja, '
        'vacío → null', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();
      cubit.setOrderType(CheckoutOrderType.delivery);
      cubit.toggleNewAddress();
      cubit.newLandmarkChanged('Casa de teja');
      cubit.newNeighborhoodChanged('La Esperanza');
      cubit.toggleSaveNewAddress();
      cubit.setNewAddressType(SavedAddressType.other);
      cubit.newAddressLabelChanged('Casa de mi mamá');

      await cubit.confirm();

      verify(
        () => saveAddress.call(
          label: 'Casa de mi mamá',
          landmark: 'Casa de teja',
          neighborhood: 'La Esperanza',
          type: SavedAddressType.other,
        ),
      ).called(1);
    });

    test('save fail → orderConfirmed igual + addressSaveFailed', () async {
      when(
        () => saveAddress.call(
          label: any(named: 'label'),
          landmark: any(named: 'landmark'),
          neighborhood: any(named: 'neighborhood'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => const Left(CheckoutServerFailure('boom')));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();
      cubit.setOrderType(CheckoutOrderType.delivery);
      cubit.toggleNewAddress();
      cubit.newLandmarkChanged('Casa de teja');
      cubit.toggleSaveNewAddress();

      await cubit.confirm();

      expect(cubit.state.orderConfirmed, isTrue);
      expect(cubit.state.addressSaveFailed, isTrue);
      expect(cubit.state.justSavedAddress, isNull);
      expect(cubit.state.savedAddresses, hasLength(2));
    });

    test('sin checkbox no hay POST (aunque el form sea válido)', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();
      cubit.setOrderType(CheckoutOrderType.delivery);
      cubit.toggleNewAddress();
      cubit.newLandmarkChanged('Casa de teja');

      await cubit.confirm();

      verifyNever(
        () => saveAddress.call(
          label: any(named: 'label'),
          landmark: any(named: 'landmark'),
          neighborhood: any(named: 'neighborhood'),
          type: any(named: 'type'),
        ),
      );
      expect(cubit.state.orderConfirmed, isTrue);
    });
  });

  group('confirmación real (§026 — POST /orders)', () {
    blocTest<CheckoutCubit, CheckoutState>(
      'válido → confirmInProgress → orderConfirmed + POST una vez',
      build: buildCubit,
      act: (cubit) async {
        await cubit.loadCheckoutData();
        await cubit.confirm();
      },
      verify: (cubit) {
        expect(cubit.state.confirmInProgress, isFalse);
        expect(cubit.state.orderConfirmed, isTrue);
        expect(cubit.state.confirmError, isNull);
        verify(() => createOrder.call(any())).called(1);
      },
    );

    test('pickup + Nequi → transfer+payerPhone, sin contactPhone ni '
        'destino de domicilio', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();

      await cubit.confirm();

      final params =
          verify(() => createOrder.call(captureAny())).captured.single
              as CreateOrderParams;
      expect(params.serviceType, 'pickup');
      expect(params.paymentMethod, 'transfer');
      expect(params.payerPhone, '3001234567');
      expect(params.contactPhone, isNull);
      expect(params.addressId, isNull);
      expect(params.newLandmark, isNull);
      expect(params.newNeighborhood, isNull);
      expect(params.deliveryLocationLink, isNull);
      expect(params.notes, isNull);
      expect(params.clientRequestId, 'req-test');
      expect(params.items, hasLength(1));
      expect(params.items.single.productId, 'p-cachorro');
      expect(params.items.single.quantity, 1);
      expect(params.items.single.modifiers, isEmpty);
    });

    test('delivery + al recibir → cash+contactPhone sin payerPhone; '
        'addressId = guardada elegida', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();
      cubit.setOrderType(CheckoutOrderType.delivery);
      cubit.selectAddress('addr-trabajo');
      cubit.setPaymentMethod(CheckoutPaymentMethod.onDelivery);

      await cubit.confirm();

      final params =
          verify(() => createOrder.call(captureAny())).captured.single
              as CreateOrderParams;
      expect(params.serviceType, 'delivery');
      expect(params.paymentMethod, 'cash');
      expect(params.payerPhone, isNull);
      expect(params.contactPhone, '3001234567');
      expect(params.addressId, 'addr-trabajo');
      expect(params.newLandmark, isNull);
    });

    test('delivery + Nequi → transfer + ambos phones; el pin adjunto '
        'viaja aunque sea el link mock (decisión #1)', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();
      cubit.setOrderType(CheckoutOrderType.delivery);
      cubit.attachDeliveryLocation();
      cubit.noteChanged('Sin picante');

      await cubit.confirm();

      final params =
          verify(() => createOrder.call(captureAny())).captured.single
              as CreateOrderParams;
      expect(params.serviceType, 'delivery');
      expect(params.paymentMethod, 'transfer');
      expect(params.payerPhone, '3001234567');
      expect(params.contactPhone, '3001234567');
      expect(params.addressId, 'addr-casa');
      expect(params.deliveryLocationLink, kCheckoutMockLocationLink);
      expect(params.notes, 'Sin picante');
    });

    test('"new" sin guardar → newAddress crudo (trim), addressId '
        'null', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();
      cubit.setOrderType(CheckoutOrderType.delivery);
      cubit.toggleNewAddress();
      cubit.newLandmarkChanged('  Casa de teja  ');
      cubit.newNeighborhoodChanged('La Esperanza');

      await cubit.confirm();

      final params =
          verify(() => createOrder.call(captureAny())).captured.single
              as CreateOrderParams;
      expect(params.addressId, isNull);
      expect(params.newLandmark, 'Casa de teja');
      expect(params.newNeighborhood, 'La Esperanza');
    });

    test('justSavedAddress.id viaja como addressId (guardada en el '
        'mismo confirm) — newAddress NO viaja', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();
      cubit.setOrderType(CheckoutOrderType.delivery);
      cubit.toggleNewAddress();
      cubit.newLandmarkChanged('Casa de teja');
      cubit.toggleSaveNewAddress();

      await cubit.confirm();

      final params =
          verify(() => createOrder.call(captureAny())).captured.single
              as CreateOrderParams;
      expect(params.addressId, 'addr-nueva');
      expect(params.newLandmark, isNull);
      expect(params.newNeighborhood, isNull);
    });

    test('ítem con modificadores → optionId/action/replacesOptionId '
        'del carrito al comando', () async {
      cartCubit.addItem(
        productId: 'p-perro',
        productSlug: 'perro',
        productName: 'El Perro',
        unitBase: 18000,
        modifiers: const [
          CartModifier(
            optionId: 'opt-mozzarella',
            optionName: 'Mozzarella',
            action: CartModifierAction.removed,
            priceDelta: 0,
          ),
          CartModifier(
            optionId: 'opt-tostacos',
            optionName: 'Tostacos',
            action: CartModifierAction.added,
            priceDelta: 0,
            replacesOptionId: 'opt-mozzarella',
          ),
        ],
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();

      await cubit.confirm();

      final params =
          verify(() => createOrder.call(captureAny())).captured.single
              as CreateOrderParams;
      expect(params.items, hasLength(2));
      final perro = params.items.firstWhere((i) => i.productId == 'p-perro');
      expect(perro.modifiers, hasLength(2));
      expect(perro.modifiers[0].optionId, 'opt-mozzarella');
      expect(perro.modifiers[0].action, 'removed');
      expect(perro.modifiers[0].replacesOptionId, isNull);
      expect(perro.modifiers[1].optionId, 'opt-tostacos');
      expect(perro.modifiers[1].action, 'added');
      expect(perro.modifiers[1].replacesOptionId, 'opt-mozzarella');
    });

    test('4xx → confirmError con copy rechazo l10n (el motivo del '
        'servidor llega en inglés — nunca se muestra), CTA libre '
        'para el retry', () async {
      when(() => createOrder.call(any())).thenAnswer(
        (_) async => const Left(
          CheckoutOrderRejectedFailure('El perro de la casa se agotó'),
        ),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();

      await cubit.confirm();

      expect(cubit.state.orderConfirmed, isFalse);
      expect(cubit.state.confirmInProgress, isFalse);
      expect(
        cubit.state.confirmError,
        'El local no pudo tomar tu pedido — revísalo e inténtalo de nuevo',
      );
    });

    test('offline → confirmError = l10n de sin conexión', () async {
      when(() => createOrder.call(any()))
          .thenAnswer((_) async => const Left(CheckoutOfflineFailure()));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();

      await cubit.confirm();

      expect(
        cubit.state.confirmError,
        'Sin internet — revisa tu conexión e inténtalo de nuevo',
      );
    });

    test('5xx/inesperado → confirmError = l10n genérico', () async {
      when(() => createOrder.call(any()))
          .thenAnswer((_) async => const Left(CheckoutServerFailure('boom')));
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();

      await cubit.confirm();

      expect(
        cubit.state.confirmError,
        'No pudimos confirmar tu pedido — inténtalo de nuevo',
      );
    });

    test('retry tras fallo: mismo clientRequestId y saveAddress NO se '
        're-llama cuando justSavedAddress ya existe', () async {
      var calls = 0;
      when(() => createOrder.call(any())).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? const Left(CheckoutServerFailure('boom'))
            : const Right(_placed);
      });
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();
      cubit.setOrderType(CheckoutOrderType.delivery);
      cubit.toggleNewAddress();
      cubit.newLandmarkChanged('Casa de teja');
      cubit.toggleSaveNewAddress();

      await cubit.confirm(); // saveAddress ok, POST /orders falla
      expect(cubit.state.confirmError, isNotNull);
      expect(cubit.state.justSavedAddress?.id, 'addr-nueva');

      await cubit.confirm(); // retry — la dirección ya está persistida

      verify(
        () => saveAddress.call(
          label: any(named: 'label'),
          landmark: any(named: 'landmark'),
          neighborhood: any(named: 'neighborhood'),
          type: any(named: 'type'),
        ),
      ).called(1);
      final captured = verify(() => createOrder.call(captureAny())).captured;
      expect(captured, hasLength(2));
      // Idempotencia (§015): ambos intentos llevan el MISMO
      // clientRequestId y la recién guardada va como addressId.
      for (final p in captured.cast<CreateOrderParams>()) {
        expect(p.clientRequestId, 'req-test');
        expect(p.addressId, 'addr-nueva');
      }
      expect(cubit.state.orderConfirmed, isTrue);
      expect(cubit.state.confirmError, isNull);
    });

    test('doble tap durante el POST no dispara dos llamadas', () async {
      final gate = Completer<Either<CheckoutFailure, PlacedOrder>>();
      when(() => createOrder.call(any())).thenAnswer((_) => gate.future);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();

      unawaited(cubit.confirm());
      unawaited(cubit.confirm()); // confirmInProgress → no-op
      gate.complete(const Right(_placed));
      await Future<void>.delayed(Duration.zero);

      verify(() => createOrder.call(any())).called(1);
      expect(cubit.state.orderConfirmed, isTrue);
    });
  });

  group('errores se limpian al editar', () {
    test('elegir dirección limpia showAddressError', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();
      cubit.setOrderType(CheckoutOrderType.delivery);
      cubit.toggleNewAddress();
      await cubit.confirm();
      expect(cubit.state.showAddressError, isTrue);

      cubit.selectAddress('addr-casa');
      expect(cubit.state.showAddressError, isFalse);
    });

    test('editar el celular limpia showNequiPhoneError', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();
      cubit.nequiPhoneChanged('12345');
      await cubit.confirm();
      expect(cubit.state.showNequiPhoneError, isTrue);

      cubit.nequiPhoneChanged('3109876543');
      expect(cubit.state.showNequiPhoneError, isFalse);
    });

    test('editar el contacto limpia showContactPhoneError (§024)', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();
      cubit.setOrderType(CheckoutOrderType.delivery);
      cubit.contactPhoneChanged('');
      await cubit.confirm();
      expect(cubit.state.showContactPhoneError, isTrue);

      cubit.contactPhoneChanged('3109876543');
      expect(cubit.state.showContactPhoneError, isFalse);
    });

    test('volver a pickup limpia el error de dirección', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.loadCheckoutData();
      cubit.setOrderType(CheckoutOrderType.delivery);
      cubit.toggleNewAddress();
      await cubit.confirm();
      expect(cubit.state.showAddressError, isTrue);

      cubit.setOrderType(CheckoutOrderType.pickup);
      expect(cubit.state.showAddressError, isFalse);
    });
  });
}
