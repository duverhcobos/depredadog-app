import 'package:dio/dio.dart';

import '../../auth/auth_storage_keys.dart';
import '../../auth/token_refresh_service.dart';
import '../../storage/interfaces/i_secure_storage.dart';

/// SOLID (SRP): adjunta `Authorization: Bearer <token>` a cada request
/// saliente si hay sesión guardada y, al recibir 401, ejecuta el retry
/// del ciclo de /auth/refresh (propuesta 015): `refresh()` → reintenta la
/// request original UNA sola vez con el Bearer nuevo via `dio.fetch` —
/// el 401 nunca alcanza los flujos de dominio. Marcador
/// `extra['retried']` = jamás loop; el path `/auth/refresh` se omite (la
/// llamada de refresh no se reintenta a sí misma — anti-recursión).
class AuthInterceptor extends Interceptor {
  /// [refresherResolver] y [dioResolver] son RESOLVERS diferidos, no
  /// instancias: este interceptor se construye dentro de la factory de
  /// DioNetworkServiceImpl — resolver TokenRefreshService en ese momento
  /// re-entraría a INetworkService → impl con su factory aún en curso
  /// (get_it aborta con "circular dependency"). Ambos se resuelven recién
  /// al primer 401, cuando el grafo de DI ya existe completo.
  AuthInterceptor({
    required this._secureStorage,
    required this._refresherResolver,
    required this._dioResolver,
  });

  final ISecureStorage _secureStorage;
  final TokenRefreshService Function() _refresherResolver;
  final Dio Function() _dioResolver;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _secureStorage.read(AuthStorageKeys.accessToken);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Solo 401, una sola vez por request (extra['retried']) y nunca sobre
    // la propia llamada de refresh. Cualquier otro caso propaga como hoy.
    if (err.response?.statusCode != 401 ||
        err.requestOptions.extra['retried'] == true ||
        err.requestOptions.path == '/auth/refresh') {
      handler.next(err);
      return;
    }
    final refreshed = await _refresherResolver().refresh();
    if (!refreshed) {
      // Refresh imposible (sin refresh token, rechazado o falla
      // transitoria): el 401 original llega al caller como hoy.
      handler.next(err);
      return;
    }
    // El refresh escribió el par nuevo — el Bearer del retry es el access
    // token recién rotado, leído del storage (no del response del POST).
    final newToken = await _secureStorage.read(AuthStorageKeys.accessToken);
    if (newToken == null || newToken.isEmpty) {
      // Race rara: refresh reportó éxito pero la clave no está (delete
      // concurrente). Reintentar mandaría el literal "Bearer null".
      handler.next(err);
      return;
    }
    final retryOptions = err.requestOptions.copyWith(
      headers: {
        ...err.requestOptions.headers,
        'Authorization': 'Bearer $newToken',
      },
      extra: {...err.requestOptions.extra, 'retried': true},
    );
    try {
      // fetch vuelve a correr la cadena completa: onRequest adjunta de
      // nuevo el Bearer (ya es el nuevo — idempotente). Si el retry da
      // 401 otra vez, extra['retried'] corta el loop y ese error propaga.
      final response = await _dioResolver().fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }
}
