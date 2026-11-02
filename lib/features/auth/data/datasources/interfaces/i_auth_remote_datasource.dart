import '../../models/user_model.dart';

/// Resultado crudo de los endpoints que emiten sesión (/auth/login,
/// /auth/verify-email, /auth/reset-password, /auth/google) — el repository
/// decide qué hacer con cada token
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
  /// /auth/register devuelve solo el UserResponseDto (sin tokens — la
  /// cuenta queda pending_verification), así que no usa LoginResult.
  /// Los opcionales llegan null → la impl omite la clave en el body.
  Future<UserModel> register({
    required String email,
    required String password,
    required String firstName,
    String? secondName,
    required String firstLastName,
    String? secondLastName,
    String? phone,
    String? deviceFingerprint,
    String? platform,
  });

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

  /// /auth/forgot-password responde 200 siempre (anti-enumeración) — no
  /// hay forma de saber si el correo existe; sin fingerprint (el endpoint
  /// no lo recibe: no emite sesión).
  Future<void> forgotPassword({required String email});

  /// /auth/check-reset-code: el código existe, no está consumido ni
  /// expirado — el chequeo NO lo consume (sigue vivo para resetPassword).
  Future<void> checkResetCode({required String email, required String code});

  /// /auth/reset-password devuelve la misma IssuedSession que login —
  /// se reutiliza LoginResult (auto-login).
  Future<LoginResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
    String? deviceFingerprint,
    String? platform,
  });

  /// /auth/google — mismo LoginResult que login/verify/reset (el endpoint
  /// emite IssuedSession). El idToken sale del SDK de Google (gateway);
  /// el repository lo pasa junto a fingerprint/platform como en login.
  Future<LoginResult> googleLogin({
    required String idToken,
    String? deviceFingerprint,
    String? platform,
  });

  /// GET /auth/me — el AuthInterceptor adjunta el Bearer guardado; acá no
  /// se arman headers. Devuelve el usuario crudo (UserResponseDto).
  Future<UserModel> getMe();
}
