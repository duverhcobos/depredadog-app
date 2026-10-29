import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../models/user_model.dart';
import '../interfaces/i_auth_remote_datasource.dart';

/// SOLID (SRP): solo construye el body y parsea la respuesta de
/// /auth/login. Nunca loguea email/password ni los tokens recibidos.
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
}
