import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';
import 'package:depredadog_app/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:depredadog_app/features/profile/presentation/cubit/profile_state.dart';

void main() {
  ProfileCubit buildCubit() => ProfileCubit();

  group('ProfileCubit (§030/§030.1 — mock de presentación)', () {
    test('estado inicial → usuario mock + referral + loyalty mocks', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state.user, kMockProfileUser);
      expect(cubit.state.user!.firstName, 'Ana');
      expect(cubit.state.user!.email, 'ana@test.com');
      expect(cubit.state.referralCode, 'XK2P9QRD');
      expect(cubit.state.loyaltyPoints, 120);
      expect(cubit.state.referredCount, 2);
      expect(cubit.state.loggingOut, isFalse);
    });

    blocTest<ProfileCubit, ProfileState>(
      'updateUser (§030.1) → reemplaza el usuario del state '
      '(PATCH /auth/me es integración; conserva referral/loyalty)',
      build: buildCubit,
      act: (cubit) => cubit.updateUser(
        const User(
          id: 'mock-u1',
          email: 'ana@test.com',
          firstName: 'Ana María',
          secondName: 'José',
          firstLastName: 'López',
          phone: '3009876543',
          role: 'customer',
          status: 'active',
        ),
      ),
      verify: (cubit) {
        final user = cubit.state.user!;
        expect(user.firstName, 'Ana María');
        expect(user.secondName, 'José');
        expect(user.phone, '3009876543');
        // Resto del state intacto — solo user cambia.
        expect(cubit.state.referralCode, 'XK2P9QRD');
        expect(cubit.state.loyaltyPoints, 120);
        expect(cubit.state.referredCount, 2);
      },
    );

    test('logout (fase 1) → stub que resuelve sin mutar el estado', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);
      final before = cubit.state;

      await cubit.logout();

      expect(cubit.state, before);
    });

    test('ProfileState.copyWith conserva campos no pasados', () {
      const state = ProfileState(
        user: kMockProfileUser,
        referralCode: 'ABC123',
        loyaltyPoints: 50,
        referredCount: 1,
        loggingOut: true,
      );
      final copy = state.copyWith(referralCode: 'XYZ789');

      expect(copy.user, kMockProfileUser);
      expect(copy.referralCode, 'XYZ789');
      expect(copy.loyaltyPoints, 50);
      expect(copy.referredCount, 1);
      expect(copy.loggingOut, isTrue);
    });
  });
}
