import '../logging/interfaces/i_logger_service.dart';
import '../network/exceptions/network_exception.dart';
import '../network/interfaces/i_network_service.dart';
import '../storage/interfaces/i_secure_storage.dart';
import 'auth_session.dart';
import 'auth_storage_keys.dart';

/// SOLID (SRP): única clase que conoce `POST /auth/refresh` y el lifecycle
/// del refresh token — lo lee del secure storage, POSTea, persiste el par
/// rotado y decide el destino de cada fallo. Es concern de transporte
/// (propuesta 015): los flujos de dominio nunca ven el 401 — el
/// AuthInterceptor los reintenta transparente.
///
/// Single-flight: `refresh()` deduplica 401s concurrentes — varios
/// requests disparan a la vez → un solo POST en vuelo → todos comparten
/// el mismo `Future<bool>` y reintentan juntos.
class TokenRefreshService {
  TokenRefreshService({
    required this._networkService,
    required this._secureStorage,
    required this._session,
    required this._logger,
  });

  final INetworkService _networkService;
  final ISecureStorage _secureStorage;
  final AuthSession _session;
  final ILoggerService _logger;

  /// Refresh en vuelo — null cuando no hay ninguno. El whenComplete lo
  /// limpia al terminar (éxito o error) para habilitar el próximo.
  Future<bool>? _inFlight;

  /// `true` si el refresh rotó los tokens (el caller reintenta su request
  /// con el Bearer nuevo); `false` si no hay refresh token, el backend lo
  /// rechazó (sesión cerrada) o la llamada falló (reintento posterior).
  Future<bool> refresh() =>
      _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);

  Future<bool> _doRefresh() async {
    final refreshToken = await _secureStorage.read(
      AuthStorageKeys.refreshToken,
    );
    if (refreshToken == null || refreshToken.isEmpty) {
      // Sin refresh token guardado no hay nada que intentar — ni la red
      // se toca. La sesión ya está (o nunca estuvo) cerrada.
      return false;
    }
    try {
      // POST público — el AuthInterceptor adjunta el Bearer expirado,
      // inofensivo para el endpoint @Public. Rotación: el refresh
      // devuelto reemplaza al anterior.
      final response = await _networkService.post(
        '/auth/refresh',
        body: {'refreshToken': refreshToken},
      );
      if (response is! Map<String, dynamic>) {
        _logger.warning(
          'POST /auth/refresh → body no es un objeto JSON',
          tag: 'Auth',
        );
        return false;
      }
      final newAccess = response['accessToken'];
      final newRefresh = response['refreshToken'];
      if (newAccess is! String ||
          newAccess.isEmpty ||
          newRefresh is! String ||
          newRefresh.isEmpty) {
        _logger.warning(
          'POST /auth/refresh → body sin par de tokens válido',
          tag: 'Auth',
        );
        return false;
      }
      // Orden deliberado: refresh primero. Si la segunda escritura falla
      // queda access viejo + refresh nuevo (el próximo refresh se cura
      // solo); al revés quedaría un refresh rotado-inutilizable en disco
      // → detección de reuso del backend → logout forzado.
      await _secureStorage.write(AuthStorageKeys.refreshToken, newRefresh);
      await _secureStorage.write(AuthStorageKeys.accessToken, newAccess);
      _logger.debug('POST /auth/refresh → tokens rotados', tag: 'Auth');
      return true;
    } on UnauthorizedException {
      // Fallo definitivo — refresh inválido/expirado/comprometido (reuso
      // detectado por el backend): misma vía, sesión cerrada.
      await _definitiveFailure(status: 401);
      return false;
    } on ServerException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _definitiveFailure(status: e.statusCode!);
        return false;
      }
      // 5xx u otro 4xx inesperado: transitorio — los tokens quedan.
      _logger.warning(
        'POST /auth/refresh → ${e.statusCode} (transitorio, tokens conservados)',
        tag: 'Auth',
      );
      return false;
    } catch (e) {
      // Transitorio (NoConnectionException, timeout, formato, etc.): los
      // tokens NO se borran — el próximo 401 vuelve a intentar el refresh.
      _logger.warning(
        'POST /auth/refresh falló (transitorio, tokens conservados): ${e.runtimeType}',
        tag: 'Auth',
      );
      return false;
    }
  }

  /// Rechazo definitivo del refresh token: borra el par de claves del
  /// secure storage y desmarca la sesión en memoria — el guard expulsa a
  /// /login en la próxima navegación (limitación aceptada: no navega solo).
  Future<void> _definitiveFailure({required int status}) async {
    // markLoggedOut primero: si el keystore lanza, el flag en RAM no
    // puede quedar marcando una sesión cuyos tokens ya no existen. El
    // borrado va protegido por el mismo motivo — un throw acá rompería
    // el contrato de refresh() (debe devolver false, no lanzar).
    _session.markLoggedOut();
    try {
      await _secureStorage.deleteKeys(const [
        AuthStorageKeys.accessToken,
        AuthStorageKeys.refreshToken,
      ]);
    } catch (_) {}
    // SEGURIDAD: jamás loguear tokens — solo el status y la acción tomada.
    _logger.warning(
      'POST /auth/refresh → $status — sesión expirada, tokens eliminados',
      tag: 'Auth',
    );
  }
}
