import '../../models/user_model.dart';

/// Resultado crudo de los endpoints que emiten sesión (/auth/login,
/// /auth/verify-email) — el repository decide qué hacer con cada token
/// (dónde persistirlos); el datasource solo parsea la respuesta.
class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserModel user;
}

abstract class IAuthRemoteDataSource {
  Future<LoginResult> login({
    required String email,
    required String password,
    String? deviceFingerprint,
    String? platform,
  });

  /// /auth/verify-email devuelve la misma IssuedSession que login —
  /// se reutiliza LoginResult.
  Future<LoginResult> verifyEmail({
    required String email,
    required String code,
    String? deviceFingerprint,
    String? platform,
  });

  Future<void> resendVerification({required String email});

  /// GET /auth/me — el AuthInterceptor adjunta el Bearer guardado; acá no
  /// se arman headers. Devuelve el usuario crudo (UserResponseDto).
  Future<UserModel> getMe();
}
