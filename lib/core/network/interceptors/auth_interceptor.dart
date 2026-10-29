import 'package:dio/dio.dart';

import '../../auth/auth_storage_keys.dart';
import '../../storage/interfaces/i_secure_storage.dart';

/// SOLID (SRP): solo adjunta `Authorization: Bearer <token>` a cada
/// request saliente si hay sesión guardada. El refresh automático al
/// recibir 401 se agrega en el ciclo de integración de /auth/refresh —
/// hasta entonces, un 401 en un endpoint protegido simplemente falla
/// (el caller lo ve como UnauthorizedException).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this._secureStorage});

  final ISecureStorage _secureStorage;

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
}
