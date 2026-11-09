import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/checkout/domain/entities/saved_address.dart';
import 'package:depredadog_app/features/checkout/domain/failures/checkout_failure.dart';
import 'package:depredadog_app/features/checkout/domain/repositories/i_checkout_repository.dart';
import 'package:depredadog_app/features/checkout/domain/use_cases/save_address_use_case.dart';

class MockCheckoutRepository extends Mock implements ICheckoutRepository {}

void main() {
  late MockCheckoutRepository repo;
  late SaveAddressUseCase useCase;

  const saved = SavedAddress(
    id: 'a-9',
    label: 'Casa',
    landmark: 'Frente a la cancha',
    neighborhood: 'La Esperanza',
    type: SavedAddressType.home,
  );

  setUpAll(() {
    registerFallbackValue(SavedAddressType.home);
  });

  setUp(() {
    repo = MockCheckoutRepository();
    useCase = SaveAddressUseCase(repo);
  });

  test('delegación: mismos args al repo y devuelve su Either', () async {
    when(
      () => repo.saveAddress(
        label: 'Casa',
        landmark: 'Frente a la cancha',
        neighborhood: 'La Esperanza',
        type: SavedAddressType.home,
      ),
    ).thenAnswer((_) async => const Right(saved));

    final result = await useCase(
      label: 'Casa',
      landmark: 'Frente a la cancha',
      neighborhood: 'La Esperanza',
      type: SavedAddressType.home,
    );

    expect(result, const Right<CheckoutFailure, SavedAddress>(saved));
    verify(
      () => repo.saveAddress(
        label: 'Casa',
        landmark: 'Frente a la cancha',
        neighborhood: 'La Esperanza',
        type: SavedAddressType.home,
      ),
    ).called(1);
  });

  test('el Left del repo viaja sin tocar', () async {
    when(
      () => repo.saveAddress(
        label: any(named: 'label'),
        landmark: any(named: 'landmark'),
        neighborhood: any(named: 'neighborhood'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => const Left(CheckoutOfflineFailure()));

    final result = await useCase(
      label: 'Casa',
      landmark: 'Frente a la cancha',
      type: SavedAddressType.home,
    );

    expect(result.isLeft(), isTrue);
  });
}
