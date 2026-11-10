import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/features/store/domain/entities/store_open_state.dart';
import 'package:depredadog_app/features/store/domain/failures/store_failure.dart';
import 'package:depredadog_app/features/store/domain/use_cases/get_store_open_state.dart';
import 'package:depredadog_app/features/store/presentation/cubit/store_status_cubit.dart';

class MockGetStoreOpenState extends Mock implements GetStoreOpenStateUseCase {}

void main() {
  late MockGetStoreOpenState getOpenState;

  StoreStatusCubit buildCubit() => StoreStatusCubit(getOpenState: getOpenState);

  setUp(() {
    getOpenState = MockGetStoreOpenState();
  });

  test('estado inicial → unknown (aún no se consultó)', () {
    final cubit = buildCubit();
    addTearDown(cubit.close);

    expect(cubit.state, StoreOpenState.unknown);
  });

  group('refresh (§029)', () {
    blocTest<StoreStatusCubit, StoreOpenState>(
      'isOpen:true → open',
      build: () {
        when(() => getOpenState())
            .thenAnswer((_) async => const Right(StoreOpenState.open));
        return buildCubit();
      },
      act: (cubit) => cubit.refresh(),
      expect: () => [StoreOpenState.open],
    );

    blocTest<StoreStatusCubit, StoreOpenState>(
      'isOpen:false → closed',
      build: () {
        when(() => getOpenState())
            .thenAnswer((_) async => const Right(StoreOpenState.closed));
        return buildCubit();
      },
      act: (cubit) => cubit.refresh(),
      expect: () => [StoreOpenState.closed],
    );

    blocTest<StoreStatusCubit, StoreOpenState>(
      'fallo con estado unknown → sigue unknown (re-emite unknown: '
      'un fallo nunca finge cerrado)',
      build: () {
        when(() => getOpenState()).thenAnswer(
          (_) async => const Left(StoreFetchFailure('Sin conexión')),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.refresh(),
      expect: () => [StoreOpenState.unknown],
      verify: (cubit) => expect(cubit.state, StoreOpenState.unknown),
    );

    blocTest<StoreStatusCubit, StoreOpenState>(
      'fallo con estado conocido → conserva el último valor (un '
      'parpadeo de red no apaga el chip ni bloquea el carrito)',
      build: () {
        when(() => getOpenState())
            .thenAnswer((_) async => const Left(StoreFetchFailure('boom')));
        return buildCubit();
      },
      seed: () => StoreOpenState.open,
      act: (cubit) => cubit.refresh(),
      expect: () => <StoreOpenState>[],
      verify: (cubit) => expect(cubit.state, StoreOpenState.open),
    );

    blocTest<StoreStatusCubit, StoreOpenState>(
      'segundo refresh con otro valor → re-emite (el estado sí '
      'cambia cuando el fetch responde)',
      build: () {
        var calls = 0;
        when(() => getOpenState()).thenAnswer((_) async {
          calls++;
          return calls == 1
              ? const Right(StoreOpenState.open)
              : const Right(StoreOpenState.closed);
        });
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.refresh();
        await cubit.refresh();
      },
      expect: () => [StoreOpenState.open, StoreOpenState.closed],
    );
  });
}
