/// Excepciones de infraestructura de red. Los repositories las mapean a
/// Failure de dominio (regla 6 SOLID) — la UI nunca las ve.
sealed class NetworkException implements Exception {
  const NetworkException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;
}

/// Sin conectividad detectada por INetworkInfo antes de la llamada.
class NoConnectionException extends NetworkException {
  const NoConnectionException() : super('No internet connection');
}

/// El servidor respondió con error (4xx/5xx) o timeout.
class ServerException extends NetworkException {
  const ServerException(super.message, {super.statusCode});
}

/// Respuesta 401 — la sesión expiró o el token es inválido.
/// (La feature auth la usa para forzar logout/refresh.)
class UnauthorizedException extends NetworkException {
  const UnauthorizedException() : super('Unauthorized', statusCode: 401);
}
