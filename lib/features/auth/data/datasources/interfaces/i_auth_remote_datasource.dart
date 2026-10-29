import '../../models/user_model.dart';

/// Resultado crudo de /auth/login — el repository decide qué hacer con
/// cada token (dónde persistirlos); el datasource solo parsea la respuesta.
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
}
