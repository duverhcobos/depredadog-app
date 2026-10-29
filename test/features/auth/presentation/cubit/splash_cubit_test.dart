import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/auth/auth_session.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/auth/domain/failures/auth_failure.dart';
import 'package:depredadog_app/features/auth/domain/use_cases/restore_session_use_case.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/splash_cubit.dart';
import 'package:depredadog_app/features/auth/presentation/cubit/splash_state.dart';

class MockRestoreSessionUseCase extends Mock implements RestoreSessionUseCase {}

void main() {
  late MockRestoreSessionUseCase useCase;
  late AuthSession authSession;

  const user = User(
    id: 'u1',
    email: 'test@depredadog.com',
    firstName: 'Test',
    lastName: 'User',
    role: 'customer',
    status: 'active',
  );

  setUp(() {
    useCase = MockRestoreSessionUseCase();
    authSession = AuthSession();
  });

  SplashCubit buildCubit() =>
      SplashCubit(restoreSessionUseCase: useCase, authSession: authSession);

  group('SplashCubit.restoreSession', () {
    blocTest<SplashCubit, SplashState>(
      'sesión válida: marca AuthSession con el user y emite restored',
      build: buildCubit,
      setUp: () =>
          when(() => useCase()).thenAnswer((_) async => const Right(user)),
      act: (cubit) => cubit.restoreSession(),
      expect: () => [
        isA<SplashState>().having(
          (s) => s.status,
          'status',
          SplashStatus.restored,
        ),
      ],
      verify: (_) {
        expect(authSession.isAuthenticated, isTrue);
        expect(authSession.currentUser, user);
      },
    );

    blocTest<SplashCubit, SplashState>(
      'sesión inválida/ausente: emite guest sin tocar AuthSession',
      build: buildCubit,
      setUp: () =>
          when(() => useCase())
              .thenAnswer((_) async => const Left(NoStoredSessionFailure())),
      act: (cubit) => cubit.restoreSession(),
      expect: () => [
        isA<SplashState>().having(
          (s) => s.status,
          'status',
          SplashStatus.guest,
        ),
      ],
      verify: (_) {
        expect(authSession.isAuthenticated, isFalse);
        expect(authSession.currentUser, isNull);
      },
    );

    blocTest<SplashCubit, SplashState>(
      'sesión expirada (401): también guest — el cubit no distingue motivos',
      build: buildCubit,
      setUp: () =>
          when(() => useCase())
              .thenAnswer((_) async => const Left(SessionExpiredFailure())),
      act: (cubit) => cubit.restoreSession(),
      expect: () => [
        isA<SplashState>().having(
          (s) => s.status,
          'status',
          SplashStatus.guest,
        ),
      ],
      verify: (_) => expect(authSession.isAuthenticated, isFalse),
    );
  });
}
