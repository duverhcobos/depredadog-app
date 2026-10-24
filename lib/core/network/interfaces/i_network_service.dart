/// Puerto HTTP de la app. Devuelve el body decodificado o lanza
/// NetworkException — los callers nunca ven DioException.
abstract class INetworkService {
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  });

  Future<dynamic> put(String path, {Object? body, Map<String, String>? headers});

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  });

  Future<dynamic> delete(String path, {Map<String, String>? headers});
}
