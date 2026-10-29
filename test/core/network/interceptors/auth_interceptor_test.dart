import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/auth/auth_storage_keys.dart';
import 'package:depredadog_app/core/network/interceptors/auth_interceptor.dart';
import 'package:depredadog_app/core/storage/interfaces/i_secure_storage.dart';

class MockSecureStorage extends Mock implements ISecureStorage {}

void main() {
  late MockSecureStorage storage;
  late AuthInterceptor interceptor;

  setUp(() {
    storage = MockSecureStorage();
    interceptor = AuthInterceptor(secureStorage: storage);
  });

  RequestOptions buildOptions() => RequestOptions(path: '/auth/me');

  /// `onRequest` es `void async` — un timer de duración cero drena los
  /// microtasks pendientes (la lectura del storage + el handler.next).
  Future<void> drain() => Future<void>.delayed(Duration.zero);

  group('AuthInterceptor.onRequest', () {
    test('con token guardado adjunta Authorization: Bearer', () async {
      when(() => storage.read(AuthStorageKeys.accessToken))
          .thenAnswer((_) async => 'token-123');
      final options = buildOptions();
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);
      await drain();

      expect(options.headers['Authorization'], 'Bearer token-123');
    });

    test('sin token guardado no toca los headers', () async {
      when(() => storage.read(AuthStorageKeys.accessToken))
          .thenAnswer((_) async => null);
      final options = buildOptions();
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);
      await drain();

      expect(options.headers.containsKey('Authorization'), isFalse);
    });

    test('token vacío no adjunta header', () async {
      when(() => storage.read(AuthStorageKeys.accessToken))
          .thenAnswer((_) async => '');
      final options = buildOptions();
      final handler = RequestInterceptorHandler();

      interceptor.onRequest(options, handler);
      await drain();

      expect(options.headers.containsKey('Authorization'), isFalse);
    });
  });
}
