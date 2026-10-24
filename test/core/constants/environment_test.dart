import 'package:flutter_test/flutter_test.dart';
import 'package:depredadog_app/core/constants/environment/environment.dart';

void main() {
  group('Environment', () {
    test('sin --dart-define cae en dev con URL de emulador Android', () {
      // En flutter test no hay dart-defines → defaults
      expect(Environment.currentEnvironment, EnvType.dev);
      expect(Environment.apiBaseUrl, 'http://10.0.2.2:3000');
      expect(Environment.isDev, isTrue);
      expect(Environment.isProd, isFalse);
    });
  });
}
