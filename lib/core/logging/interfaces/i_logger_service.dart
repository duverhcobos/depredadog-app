/// Puerto de logging de la app (DIP). Nunca usar print() — regla 12 SOLID.
/// Prohibido loguear tokens, contraseñas ni cuerpos de request/response.
abstract class ILoggerService {
  void debug(String message, {String? tag});
  void info(String message, {String? tag});
  void warning(String message, {String? tag});
  void error(String message, {Object? error, StackTrace? stackTrace, String? tag});
}
