import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../models/user_model.dart';
import '../interfaces/i_auth_remote_datasource.dart';

/// SOLID (SRP): solo construye el body y parsea la respuesta de los
/// endpoints de auth — públicos (/auth/login, /auth/verify-email,
/// /auth/resend-verification) y autenticados (/auth/me — el Bearer lo
/// adjunta el AuthInterceptor, acá no se arman headers). Nunca loguea
/// email/password ni los tokens.
class AuthRemoteDataSourceImpl implements IAuthRemoteDataSource {
  const AuthRemoteDataSourceImpl({required this._networkService});

  final INetworkService _networkService;

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
    String? deviceFingerprint,
    String? platform,
  }) async {
    final response = await _networkService.post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
        'deviceFingerprint': ?deviceFingerprint,
        'platform': ?platform,
      },
    );
    final map = response as Map<String, dynamic>;
    return LoginResult(
      accessToken: map['accessToken'] as String,
      refreshToken: map['refreshToken'] as String,
      user: UserModel.fromJson(map['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<LoginResult> verifyEmail({
    required String email,
    required String code,
    String? deviceFingerprint,
    String? platform,
  }) async {
    final response = await _networkService.post(
      '/auth/verify-email',
      body: {
        'email': email,
        'code': code,
        'deviceFingerprint': ?deviceFingerprint,
        'platform': ?platform,
      },
    );
    final map = response as Map<String, dynamic>;
    return LoginResult(
      accessToken: map['accessToken'] as String,
      refreshToken: map['refreshToken'] as String,
      user: UserModel.fromJson(map['user'] as Map<String, dynamic>),
    );
  }

  @override
  Future<void> resendVerification({required String email}) {
    return _networkService.post(
      '/auth/resend-verification',
      body: {'email': email},
    );
  }

  @override
  Future<UserModel> getMe() async {
    final response = await _networkService.get('/auth/me');
    return UserModel.fromJson(response as Map<String, dynamic>);
  }
}
