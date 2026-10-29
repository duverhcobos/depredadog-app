import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/auth/auth_session.dart';
import 'package:depredadog_app/features/auth/domain/entities/user.dart';

void main() {
  const user = User(
    id: 'u1',
    email: 'test@depredadog.com',
    firstName: 'Test',
    lastName: 'User',
    role: 'customer',
    status: 'active',
  );

  group('AuthSession', () {
    test('arranca sin sesión y sin usuario', () {
      final session = AuthSession();

      expect(session.isAuthenticated, isFalse);
      expect(session.currentUser, isNull);
    });

    test('markAuthenticated guarda el flag y el usuario', () {
      final session = AuthSession()..markAuthenticated(user);

      expect(session.isAuthenticated, isTrue);
      expect(session.currentUser, user);
    });

    test('markLoggedOut limpia el flag y el usuario', () {
      final session = AuthSession()..markAuthenticated(user);

      session.markLoggedOut();

      expect(session.isAuthenticated, isFalse);
      expect(session.currentUser, isNull);
    });
  });
}
