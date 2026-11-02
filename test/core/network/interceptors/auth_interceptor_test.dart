import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:depredadog_app/core/auth/auth_storage_keys.dart';
import 'package:depredadog_app/core/auth/token_refresh_service.dart';
import 'package:depredadog_app/core/network/interceptors/auth_interceptor.dart';
import 'package:depredadog_app/core/storage/interfaces/i_secure_storage.dart';

class MockSecureStorage extends Mock implements ISecureStorage {}

class MockTokenRefreshService extends Mock implements TokenRefreshService {}

class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

void main() {
  late MockSecureStorage storage;
  late MockTokenRefreshService refresher;
  late AuthInterceptor interceptor;

  setUp(() {
    storage = MockSecureStorage();
    refresher = MockTokenRefreshService();
    interceptor = AuthInterceptor(
      secureStorage: storage,
      refresherResolver: () => refresher,
      dioResolver: () => Dio(),
    );
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

  // onError se prueba con un Dio real + HttpClientAdapter mockeado: el
  // retry corre la cadena de interceptores completa (onRequest vuelve a
  // adjuntar el Bearer), igual que en producción.
  group('AuthInterceptor.onError', () {
    late MockHttpClientAdapter adapter;
    late Dio dio;
    late List<RequestOptions> sent;
    late int adapterCalls;

    /// Body de respuesta que el adapter mockeado devuelve a Dio.
    ResponseBody jsonBody(String json, int status) => ResponseBody.fromString(
      json,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

    /// Stub del adapter: `respond` recibe el número de llamada (1, 2...)
    /// y devuelve el ResponseBody simulado — permite 401 → luego 200.
    void stubAdapter(ResponseBody Function(int call) respond) {
      when(() => adapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
            adapterCalls++;
            sent.add(invocation.positionalArguments[0] as RequestOptions);
            return respond(adapterCalls);
          });
    }

    setUpAll(() {
      registerFallbackValue(RequestOptions());
      registerFallbackValue(const Stream<Uint8List>.empty());
      registerFallbackValue(Future<void>.value());
    });

    setUp(() {
      adapter = MockHttpClientAdapter();
      sent = [];
      adapterCalls = 0;
      dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      // Como en DI real: el dioResolver del interceptor apunta al MISMO
      // Dio donde vive — el retry corre por este mismo adapter mockeado.
      interceptor = AuthInterceptor(
        secureStorage: storage,
        refresherResolver: () => refresher,
        dioResolver: () => dio,
      );
      dio.interceptors.add(interceptor);
    });

    test(
      '401 → refresh ok → reintenta la request con el Bearer nuevo',
      () async {
        var reads = 0;
        when(() => storage.read(AuthStorageKeys.accessToken)).thenAnswer(
          (_) async => ++reads == 1 ? 'access-viejo' : 'access-nuevo',
        );
        stubAdapter(
          (call) => call == 1
              ? jsonBody('{"message":"expired"}', 401)
              : jsonBody('{"id":"u1"}', 200),
        );
        when(() => refresher.refresh()).thenAnswer((_) async => true);

        final response = await dio.get<dynamic>('/auth/me');

        expect(response.statusCode, 200);
        expect(adapterCalls, 2);
        verify(() => refresher.refresh()).called(1);
        // La request original llevó el Bearer viejo; el retry lleva el
        // access token recién escrito por el refresh + la marca.
        expect(sent.first.headers['Authorization'], 'Bearer access-viejo');
        expect(sent.last.headers['Authorization'], 'Bearer access-nuevo');
        expect(sent.last.extra['retried'], isTrue);
        expect(sent.last.path, '/auth/me');
      },
    );

    test('request ya marcada con extra[retried] no intenta refresh', () async {
      when(() => storage.read(AuthStorageKeys.accessToken))
          .thenAnswer((_) async => 'access-viejo');
      stubAdapter((call) => jsonBody('{"message":"expired"}', 401));

      await expectLater(
        dio.get<dynamic>(
          '/auth/me',
          options: Options(extra: {'retried': true}),
        ),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      verifyNever(() => refresher.refresh());
      expect(adapterCalls, 1);
    });

    test('el 401 de /auth/refresh no se reintenta a sí mismo', () async {
      when(() => storage.read(AuthStorageKeys.accessToken))
          .thenAnswer((_) async => 'access-viejo');
      stubAdapter((call) => jsonBody('{"message":"invalid"}', 401));

      await expectLater(
        dio.post<dynamic>('/auth/refresh', data: {'refreshToken': 'r'}),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      verifyNever(() => refresher.refresh());
      expect(adapterCalls, 1);
    });

    test('refresh falla → el 401 original propaga al caller', () async {
      when(() => storage.read(AuthStorageKeys.accessToken))
          .thenAnswer((_) async => 'access-viejo');
      stubAdapter((call) => jsonBody('{"message":"expired"}', 401));
      when(() => refresher.refresh()).thenAnswer((_) async => false);

      await expectLater(
        dio.get<dynamic>('/auth/me'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      verify(() => refresher.refresh()).called(1);
      expect(adapterCalls, 1);
    });

    test(
      'si el retry también da 401, el marcador corta el loop y propaga',
      () async {
        when(() => storage.read(AuthStorageKeys.accessToken))
            .thenAnswer((_) async => 'access-nuevo');
        stubAdapter((call) => jsonBody('{"message":"expired"}', 401));
        when(() => refresher.refresh()).thenAnswer((_) async => true);

        await expectLater(
          dio.get<dynamic>('/auth/me'),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'statusCode',
              401,
            ),
          ),
        );

        // Un solo refresh + un solo retry — jamás loop.
        verify(() => refresher.refresh()).called(1);
        expect(adapterCalls, 2);
        expect(sent.last.extra['retried'], isTrue);
      },
    );

    test('errores que no son 401 no disparan refresh', () async {
      when(() => storage.read(AuthStorageKeys.accessToken))
          .thenAnswer((_) async => 'access-viejo');
      stubAdapter((call) => jsonBody('{"message":"boom"}', 500));

      await expectLater(
        dio.get<dynamic>('/auth/me'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            500,
          ),
        ),
      );

      verifyNever(() => refresher.refresh());
      expect(adapterCalls, 1);
    });
  });
}
