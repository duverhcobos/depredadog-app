import 'package:dio/dio.dart';

import '../../constants/environment/environment.dart';
import '../../logging/interfaces/i_logger_service.dart';
import '../exceptions/network_exception.dart';
import '../interfaces/i_network_service.dart';

/// Implementación Dio del puerto HTTP. Centraliza baseUrl, timeouts,
/// mapeo DioException → NetworkException y logging de requests en dev.
class DioNetworkServiceImpl implements INetworkService {
  DioNetworkServiceImpl({
    required this._logger,
    List<Interceptor> extraInterceptors = const [],
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: Environment.apiBaseUrl,
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 15),
           sendTimeout: const Duration(seconds: 15),
           headers: {'Content-Type': 'application/json'},
         ),
       ) {
    // Interceptores propios de cada feature (ej. AuthInterceptor) primero,
    // para que si el LogInterceptor llegara a reactivar el log de headers
    // más adelante, siga viendo la request ya completa (orden recomendado
    // por la doc de LogInterceptor: "debe ser el último agregado").
    _dio.interceptors.addAll(extraInterceptors);
    if (Environment.isDev) {
      _dio.interceptors.add(
        // SEGURIDAD: requestHeader/responseHeader se fuerzan a false —
        // por defecto Dio los deja en `true`; con el AuthInterceptor
        // mandando "Authorization: Bearer <token>" eso imprimiría el
        // token en la consola de debug. Nunca loguear tokens.
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          requestHeader: false,
          responseHeader: false,
        ),
      );
    }
  }

  final Dio _dio;
  final ILoggerService _logger;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) => _request(
    () => _dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
      options: _opts(headers),
    ),
  );

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _request(
    () => _dio.post<dynamic>(path, data: body, options: _opts(headers)),
  );

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _request(
    () => _dio.put<dynamic>(path, data: body, options: _opts(headers)),
  );

  @override
  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _request(
    () => _dio.patch<dynamic>(path, data: body, options: _opts(headers)),
  );

  @override
  Future<dynamic> delete(String path, {Map<String, String>? headers}) =>
      _request(() => _dio.delete<dynamic>(path, options: _opts(headers)));

  Options? _opts(Map<String, String>? headers) =>
      headers == null ? null : Options(headers: headers);

  Future<dynamic> _request(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      return response.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  NetworkException _mapError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) return const UnauthorizedException();
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NoConnectionException();
    }
    final serverMessage = e.response?.data is Map<String, dynamic>
        ? (e.response!.data as Map<String, dynamic>)['message']
        : null;
    _logger.warning(
      'HTTP ${e.requestOptions.method} ${e.requestOptions.path} → $status',
      tag: 'Network',
    );
    return ServerException(
      serverMessage is String
          ? serverMessage
          : (serverMessage is List && serverMessage.isNotEmpty
                ? serverMessage.first.toString()
                : 'Request failed'),
      statusCode: status,
    );
  }
}
