import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/network/exceptions/network_exception.dart';
import 'package:depredadog_app/core/network/interfaces/i_network_info.dart';
import 'package:depredadog_app/features/checkout/data/datasources/interfaces/i_checkout_remote_datasource.dart';
import 'package:depredadog_app/features/checkout/data/models/checkout_store_model.dart';
import 'package:depredadog_app/features/checkout/data/models/placed_order_model.dart';
import 'package:depredadog_app/features/checkout/data/models/saved_address_model.dart';
import 'package:depredadog_app/features/checkout/data/repositories/checkout_repository_impl.dart';
import 'package:depredadog_app/features/checkout/domain/entities/checkout_store.dart';
import 'package:depredadog_app/features/checkout/domain/entities/placed_order.dart';
import 'package:depredadog_app/features/checkout/domain/entities/saved_address.dart';
import 'package:depredadog_app/features/checkout/domain/failures/checkout_failure.dart';
import 'package:depredadog_app/features/checkout/domain/use_cases/create_order_params.dart';

class MockRemoteDataSource extends Mock implements ICheckoutRemoteDataSource {}

class MockNetworkInfo extends Mock implements INetworkInfo {}

void main() {
  late MockRemoteDataSource remote;
  late MockNetworkInfo networkInfo;
  late CheckoutRepositoryImpl repository;

  const addresses = <SavedAddressModel>[
    SavedAddressModel(
      id: 'a-1',
      label: 'Casa',
      landmark: 'Frente a la cancha',
      neighborhood: 'La Esperanza',
      type: SavedAddressType.home,
    ),
  ];
  const store = CheckoutStoreModel(
    name: 'Depredadog',
    address: 'Costado norte del parque',
    deliveryFee: 0,
    isOpen: true,
  );
  const saved = SavedAddressModel(
    id: 'a-9',
    label: 'Casa',
    landmark: 'Casa de teja',
    type: SavedAddressType.home,
  );

  setUp(() {
    remote = MockRemoteDataSource();
    networkInfo = MockNetworkInfo();
    repository = CheckoutRepositoryImpl(
      remoteDataSource: remote,
      networkInfo: networkInfo,
    );
    when(() => networkInfo.isConnected).thenAnswer((_) async => true);
  });

  group('getSavedAddresses', () {
    test('éxito con conectividad → Right(addresses)', () async {
      when(() => remote.fetchAddresses()).thenAnswer((_) async => addresses);

      final result = await repository.getSavedAddresses();

      expect(
        result,
        const Right<CheckoutFailure, List<SavedAddress>>(addresses),
      );
      verify(() => remote.fetchAddresses()).called(1);
    });

    test(
      'sin conectividad → Left(Offline) y el datasource NUNCA se llama',
      () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);

        final result = await repository.getSavedAddresses();

        expect(
          result,
          const Left<CheckoutFailure, List<SavedAddress>>(
            CheckoutOfflineFailure(),
          ),
        );
        verifyNever(() => remote.fetchAddresses());
      },
    );

    test('NoConnectionException → CheckoutOfflineFailure', () async {
      when(() => remote.fetchAddresses())
          .thenThrow(const NoConnectionException());

      final result = await repository.getSavedAddresses();

      expect(
        result,
        const Left<CheckoutFailure, List<SavedAddress>>(
          CheckoutOfflineFailure(),
        ),
      );
    });

    test('ServerException (500) → CheckoutServerFailure', () async {
      when(() => remote.fetchAddresses())
          .thenThrow(const ServerException('Internal error', statusCode: 500));

      final result = await repository.getSavedAddresses();

      expect(
        result,
        const Left<CheckoutFailure, List<SavedAddress>>(
          CheckoutServerFailure('Internal error'),
        ),
      );
    });
  });

  group('getStoreConfig', () {
    test('éxito → Right(store)', () async {
      when(() => remote.fetchStoreConfig()).thenAnswer((_) async => store);

      final result = await repository.getStoreConfig();

      expect(result, const Right<CheckoutFailure, CheckoutStore>(store));
    });

    test('sin conectividad → Left(Offline)', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repository.getStoreConfig();

      expect(
        result,
        const Left<CheckoutFailure, CheckoutStore>(CheckoutOfflineFailure()),
      );
      verifyNever(() => remote.fetchStoreConfig());
    });

    test('ServerException → CheckoutServerFailure', () async {
      when(() => remote.fetchStoreConfig())
          .thenThrow(const ServerException('boom', statusCode: 502));

      final result = await repository.getStoreConfig();

      expect(
        result,
        const Left<CheckoutFailure, CheckoutStore>(
          CheckoutServerFailure('boom'),
        ),
      );
    });

    test('error no-NetworkException (cast roto de un 200) → '
        'CheckoutServerFailure (red de seguridad)', () async {
      when(() => remote.fetchStoreConfig()).thenThrow(StateError('bad cast'));

      final result = await repository.getStoreConfig();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<CheckoutServerFailure>()),
        (_) => fail('esperaba Left'),
      );
    });
  });

  group('saveAddress', () {
    test(
      'éxito → arma el body con type.name y devuelve Right(saved)',
      () async {
        when(() => remote.createAddress(any())).thenAnswer((_) async => saved);

        final result = await repository.saveAddress(
          label: 'Casa',
          landmark: 'Casa de teja',
          neighborhood: 'La Esperanza',
          type: SavedAddressType.home,
        );

        expect(result, const Right<CheckoutFailure, SavedAddress>(saved));
        verify(
          () => remote.createAddress({
            'label': 'Casa',
            'landmark': 'Casa de teja',
            'neighborhood': 'La Esperanza',
            'type': 'home',
          }),
        ).called(1);
      },
    );

    test('neighborhood null → la key no viaja en el body', () async {
      when(() => remote.createAddress(any())).thenAnswer((_) async => saved);

      await repository.saveAddress(
        label: 'Trabajo',
        landmark: 'Segundo local del puente',
        type: SavedAddressType.work,
      );

      verify(
        () => remote.createAddress({
          'label': 'Trabajo',
          'landmark': 'Segundo local del puente',
          'type': 'work',
        }),
      ).called(1);
    });

    test('sin conectividad → Left(Offline) sin llamar al datasource', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repository.saveAddress(
        label: 'Casa',
        landmark: 'Casa de teja',
        type: SavedAddressType.home,
      );

      expect(
        result,
        const Left<CheckoutFailure, SavedAddress>(CheckoutOfflineFailure()),
      );
      verifyNever(() => remote.createAddress(any()));
    });

    test('ServerException (400) → CheckoutServerFailure', () async {
      when(() => remote.createAddress(any()))
          .thenThrow(const ServerException('label required', statusCode: 400));

      final result = await repository.saveAddress(
        label: 'Casa',
        landmark: 'Casa de teja',
        type: SavedAddressType.home,
      );

      expect(
        result,
        const Left<CheckoutFailure, SavedAddress>(
          CheckoutServerFailure('label required'),
        ),
      );
    });
  });

  group('createOrder', () {
    const placed = PlacedOrderModel(
      id: 'o-1',
      orderNumber: 7,
      status: 'pending',
      total: 28000,
    );
    const params = CreateOrderParams(
      serviceType: 'delivery',
      paymentMethod: 'cash',
      clientRequestId: 'req-1',
      addressId: 'a-1',
      contactPhone: '3001234567',
      deliveryLocationLink: 'maps.app.goo.gl/xK9fP2AbCd3',
      notes: 'Sin picante',
      items: [
        OrderItemInput(
          productId: 'p-1',
          quantity: 2,
          modifiers: [
            OrderModifierInput(optionId: 'm-1', action: 'removed'),
            OrderModifierInput(
              optionId: 'm-9',
              action: 'added',
              replacesOptionId: 'm-1',
            ),
          ],
        ),
      ],
    );

    test('éxito → Right(placed) y el wire map respeta el contrato '
        '(§015)', () async {
      when(() => remote.createOrder(any())).thenAnswer((_) async => placed);

      final result = await repository.createOrder(params);

      expect(result, const Right<CheckoutFailure, PlacedOrder>(placed));
      // replacesOptionId solo viaja en la fila added que lo trae.
      verify(
        () => remote.createOrder({
          'serviceType': 'delivery',
          'items': [
            {
              'productId': 'p-1',
              'quantity': 2,
              'modifiers': [
                {'optionId': 'm-1', 'action': 'removed', 'times': 1},
                {
                  'optionId': 'm-9',
                  'action': 'added',
                  'times': 1,
                  'replacesOptionId': 'm-1',
                },
              ],
            },
          ],
          'paymentMethod': 'cash',
          'clientRequestId': 'req-1',
          'addressId': 'a-1',
          'contactPhone': '3001234567',
          'deliveryLocationLink': 'maps.app.goo.gl/xK9fP2AbCd3',
          'notes': 'Sin picante',
        }),
      ).called(1);
    });

    test('XOR: newLandmark → newAddress{landmark,neighborhood?} y '
        'addressId NO viaja', () async {
      when(() => remote.createOrder(any())).thenAnswer((_) async => placed);

      await repository.createOrder(
        const CreateOrderParams(
          serviceType: 'delivery',
          paymentMethod: 'transfer',
          clientRequestId: 'req-2',
          newLandmark: 'Casa de teja',
          newNeighborhood: 'La Esperanza',
          payerPhone: '3109876543',
          items: [OrderItemInput(productId: 'p-2', quantity: 1)],
        ),
      );

      verify(
        () => remote.createOrder({
          'serviceType': 'delivery',
          'items': [
            {'productId': 'p-2', 'quantity': 1, 'modifiers': <dynamic>[]},
          ],
          'paymentMethod': 'transfer',
          'clientRequestId': 'req-2',
          'newAddress': {
            'landmark': 'Casa de teja',
            'neighborhood': 'La Esperanza',
          },
          'payerPhone': '3109876543',
        }),
      ).called(1);
    });

    test('sin conectividad → Left(Offline) sin llamar al datasource', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);

      final result = await repository.createOrder(params);

      expect(
        result,
        const Left<CheckoutFailure, PlacedOrder>(CheckoutOfflineFailure()),
      );
      verifyNever(() => remote.createOrder(any()));
    });

    test('NoConnectionException → CheckoutOfflineFailure', () async {
      when(() => remote.createOrder(any()))
          .thenThrow(const NoConnectionException());

      final result = await repository.createOrder(params);

      expect(
        result,
        const Left<CheckoutFailure, PlacedOrder>(CheckoutOfflineFailure()),
      );
    });

    test('409 con errorCode STORE_CLOSED → CheckoutOrderRejectedFailure '
        'con code storeClosed (§028 — el código tipa el motivo)', () async {
      when(() => remote.createOrder(any())).thenThrow(
        const ServerException(
          'Store is closed',
          statusCode: 409,
          errorCode: 'STORE_CLOSED',
        ),
      );

      final result = await repository.createOrder(params);

      expect(
        result,
        const Left<CheckoutFailure, PlacedOrder>(
          CheckoutOrderRejectedFailure(
            'Store is closed',
            code: OrderRejection.storeClosed,
          ),
        ),
      );
    });

    test('409 sin errorCode (respuesta vieja/proxy) → '
        'CheckoutOrderRejectedFailure con code unknown (§028 — el copy '
        'genérico sigue sirviendo)', () async {
      when(() => remote.createOrder(any())).thenThrow(
        const ServerException(
          'Product is no longer available',
          statusCode: 409,
        ),
      );

      final result = await repository.createOrder(params);

      expect(
        result,
        const Left<CheckoutFailure, PlacedOrder>(
          CheckoutOrderRejectedFailure(
            'Product is no longer available',
            code: OrderRejection.unknown,
          ),
        ),
      );
    });

    test('cada errorCode de dominio → su OrderRejection (§028 — la '
        'traducción vive en data, no en presentation)', () async {
      const cases = {
        'MIN_ORDER_AMOUNT': OrderRejection.minOrderAmount,
        'ORDER_CATALOG_VIOLATION': OrderRejection.catalogViolation,
        'INVALID_ORDER_DATA': OrderRejection.invalidOrderData,
      };
      for (final entry in cases.entries) {
        when(() => remote.createOrder(any())).thenThrow(
          ServerException('Rejected', statusCode: 409, errorCode: entry.key),
        );

        final result = await repository.createOrder(params);

        expect(
          result,
          Left<CheckoutFailure, PlacedOrder>(
            CheckoutOrderRejectedFailure('Rejected', code: entry.value),
          ),
          reason: '${entry.key} → ${entry.value}',
        );
      }
    });

    test('500 → CheckoutServerFailure (infraestructura, no motivo de '
        'negocio)', () async {
      when(() => remote.createOrder(any()))
          .thenThrow(const ServerException('boom', statusCode: 500));

      final result = await repository.createOrder(params);

      expect(
        result,
        const Left<CheckoutFailure, PlacedOrder>(CheckoutServerFailure('boom')),
      );
    });
  });
}
