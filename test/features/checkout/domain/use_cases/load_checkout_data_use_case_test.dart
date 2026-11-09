import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/checkout/domain/entities/checkout_store.dart';
import 'package:depredadog_app/features/checkout/domain/entities/saved_address.dart';
import 'package:depredadog_app/features/checkout/domain/failures/checkout_failure.dart';
import 'package:depredadog_app/features/checkout/domain/repositories/i_checkout_repository.dart';
import 'package:depredadog_app/features/checkout/domain/use_cases/load_checkout_data_use_case.dart';

class MockCheckoutRepository extends Mock implements ICheckoutRepository {}

void main() {
  late MockCheckoutRepository repo;
  late LoadCheckoutDataUseCase useCase;

  const addresses = <SavedAddress>[
    SavedAddress(id: 'a-1', label: 'Casa', landmark: 'Frente a la cancha'),
  ];
  const store = CheckoutStore(
    name: 'Depredadog',
    address: 'Costado norte del parque',
    deliveryFee: 0,
  );

  setUp(() {
    repo = MockCheckoutRepository();
    useCase = LoadCheckoutDataUseCase(repo);
  });

  test('ambos GET ok → cada pierna Right', () async {
    when(
      () => repo.getSavedAddresses(),
    ).thenAnswer((_) async => const Right(addresses));
    when(
      () => repo.getStoreConfig(),
    ).thenAnswer((_) async => const Right(store));

    final result = await useCase();

    expect(
      result.addresses,
      const Right<CheckoutFailure, List<SavedAddress>>(addresses),
    );
    expect(result.store, const Right<CheckoutFailure, CheckoutStore>(store));
  });

  test('una pierna falla NO tumba la otra (Either independientes)', () async {
    when(repo.getSavedAddresses).thenAnswer(
      (_) async => const Left(CheckoutServerFailure('boom')),
    );
    when(
      () => repo.getStoreConfig(),
    ).thenAnswer((_) async => const Right(store));

    final result = await useCase();

    expect(result.addresses.isLeft(), isTrue);
    expect(result.store.isRight(), isTrue);

    when(
      () => repo.getSavedAddresses(),
    ).thenAnswer((_) async => const Right(addresses));
    when(repo.getStoreConfig).thenAnswer(
      (_) async => const Left(CheckoutOfflineFailure()),
    );

    final result2 = await useCase();

    expect(result2.addresses.isRight(), isTrue);
    expect(result2.store.isLeft(), isTrue);
  });
}
