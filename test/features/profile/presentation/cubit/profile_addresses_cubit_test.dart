import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/features/checkout/domain/entities/saved_address.dart';
import 'package:depredadog_app/features/profile/presentation/cubit/profile_addresses_cubit.dart';
import 'package:depredadog_app/features/profile/presentation/cubit/profile_addresses_state.dart';

void main() {
  ProfileAddressesCubit buildCubit() => ProfileAddressesCubit();

  group('ProfileAddressesCubit (§030 — mutaciones optimistas mock)', () {
    test('estado inicial → las 3 direcciones mock, una sola default', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state.addresses, hasLength(3));
      expect(cubit.state.addresses.map((a) => a.id), ['a1', 'a2', 'a3']);
      expect(cubit.state.defaultAddress?.id, 'a1');
      expect(cubit.state.addresses.where((a) => a.isDefault), hasLength(1));
    });

    blocTest<ProfileAddressesCubit, ProfileAddressesState>(
      'markDefault → exclusividad backend: solo la marcada queda '
      'default, las demás la pierden',
      build: buildCubit,
      act: (cubit) => cubit.markDefault('a2'),
      verify: (cubit) {
        expect(cubit.state.defaultAddress?.id, 'a2');
        expect(
          cubit.state.addresses.where((a) => a.isDefault).map((a) => a.id),
          ['a2'],
        );
        // La que perdió el flag conserva el resto de sus campos.
        final a1 = cubit.state.addresses.first;
        expect(a1.id, 'a1');
        expect(a1.isDefault, isFalse);
        expect(a1.label, 'Casa');
        expect(a1.landmark, 'Casa blanca reja negra');
      },
    );

    blocTest<ProfileAddressesCubit, ProfileAddressesState>(
      'markDefault sobre la misma → idempotente',
      build: buildCubit,
      act: (cubit) => cubit.markDefault('a1'),
      verify: (cubit) {
        expect(cubit.state.defaultAddress?.id, 'a1');
        expect(cubit.state.addresses, hasLength(3));
      },
    );

    blocTest<ProfileAddressesCubit, ProfileAddressesState>(
      'delete → quita la fila de la lista',
      build: buildCubit,
      act: (cubit) => cubit.delete('a2'),
      verify: (cubit) {
        expect(cubit.state.addresses.map((a) => a.id), ['a1', 'a3']);
      },
    );

    blocTest<ProfileAddressesCubit, ProfileAddressesState>(
      'delete de la default → la primera restante hereda el flag '
      '(invariante "una sola default" — el mock simula lo que el '
      'backend garantizará, §030)',
      build: buildCubit,
      act: (cubit) => cubit.delete('a1'),
      verify: (cubit) {
        expect(cubit.state.addresses.map((a) => a.id), ['a2', 'a3']);
        expect(cubit.state.defaultAddress?.id, 'a2');
      },
    );

    blocTest<ProfileAddressesCubit, ProfileAddressesState>(
      'delete total → lista vacía sin default (nadie hereda)',
      build: buildCubit,
      act: (cubit) => cubit
        ..delete('a1')
        ..delete('a2')
        ..delete('a3'),
      verify: (cubit) {
        expect(cubit.state.addresses, isEmpty);
        expect(cubit.state.defaultAddress, isNull);
      },
    );

    blocTest<ProfileAddressesCubit, ProfileAddressesState>(
      'upsert crear → agrega al final conservando orden y flags',
      build: buildCubit,
      act: (cubit) => cubit.upsert(
        const SavedAddress(
          id: 'mock-9',
          label: 'Gym',
          landmark: 'Segundo piso del coliseo',
          type: SavedAddressType.other,
        ),
      ),
      verify: (cubit) {
        expect(cubit.state.addresses, hasLength(4));
        expect(cubit.state.addresses.last.id, 'mock-9');
        expect(cubit.state.defaultAddress?.id, 'a1');
      },
    );

    blocTest<ProfileAddressesCubit, ProfileAddressesState>(
      'upsert editar → reemplaza EN su posición y preserva isDefault '
      'del SavedAddress entrante',
      build: buildCubit,
      act: (cubit) =>
          cubit.upsert(kMockAddresses[1].copyWith(landmark: 'Oficina 305')),
      verify: (cubit) {
        expect(cubit.state.addresses, hasLength(3));
        expect(cubit.state.addresses[1].id, 'a2');
        expect(cubit.state.addresses[1].landmark, 'Oficina 305');
        expect(cubit.state.defaultAddress?.id, 'a1');
      },
    );
  });
}
