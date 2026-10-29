import 'package:dartz/dartz.dart';

import '../../../../core/device/interfaces/i_device_info_provider.dart';
import '../../../../core/network/exceptions/network_exception.dart';
import '../../../../core/network/interfaces/i_network_info.dart';
import '../../domain/entities/user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/interfaces/i_auth_local_datasource.dart';
import '../datasources/interfaces/i_auth_remote_datasource.dart';

/// SOLID (SRP/DIP): orquesta remoto + local + conectividad; traduce
/// NetworkException → AuthFailure (regla 6 SOLID) — nadie más atrapa
/// excepciones crudas de red para esta feature.
class AuthRepositoryImpl implements IAuthRepository {
  const AuthRepositoryImpl({
    required this._remoteDataSource,
    required this._localDataSource,
    required this._networkInfo,
    required this._deviceInfoProvider,
  });

  final IAuthRemoteDataSource _remoteDataSource;
  final IAuthLocalDataSource _localDataSource;
  final INetworkInfo _networkInfo;
  final IDeviceInfoProvider _deviceInfoProvider;

  @override
  Future<Either<AuthFailure, User>> login({
    required String email,
    required String password,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NoConnectionFailure());
    }
    try {
      final fingerprint = await _deviceInfoProvider.fingerprint();
      final result = await _remoteDataSource.login(
        email: email,
        password: password,
        deviceFingerprint: fingerprint,
        platform: _deviceInfoProvider.platform,
      );
      await _localDataSource.saveSession(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      return Right(result.user);
    } on NetworkException catch (e) {
      return Left(_mapFailure(e));
    } catch (e) {
      // Red de seguridad (revisor §004): un 200 malformado (cast del
      // datasource) o un PlatformException de flutter_secure_storage no
      // son NetworkException — sin este catch la excepción escaparía al
      // cubit y la UI quedaría en loading para siempre sin feedback.
      return Left(UnknownAuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<AuthFailure, User>> verifyEmail({
    required String email,
    required String code,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NoConnectionFailure());
    }
    try {
      final fingerprint = await _deviceInfoProvider.fingerprint();
      final result = await _remoteDataSource.verifyEmail(
        email: email,
        code: code,
        deviceFingerprint: fingerprint,
        platform: _deviceInfoProvider.platform,
      );
      await _localDataSource.saveSession(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      return Right(result.user);
    } on NetworkException catch (e) {
      return Left(_mapFailure(e));
    } catch (e) {
      return Left(UnknownAuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<AuthFailure, void>> resendVerification({
    required String email,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NoConnectionFailure());
    }
    try {
      await _remoteDataSource.resendVerification(email: email);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(_mapFailure(e));
    } catch (e) {
      return Left(UnknownAuthFailure(e.toString()));
    }
  }

  AuthFailure _mapFailure(NetworkException e) {
    if (e is NoConnectionException) return const NoConnectionFailure();
    // 401 en /auth/login solo significa credenciales inválidas (no sesión
    // expirada — este repositorio nunca llama endpoints autenticados).
    if (e is UnauthorizedException) return const InvalidCredentialsFailure();
    // 400 "Invalid or expired code" cubre código errado, expirado y cuenta
    // no pendiente (el backend no los distingue — anti-enumeración). Otros
    // 400 (validación de DTO) caen a Unknown — la UI ya impide formatos
    // inválidos, así que un 400 ajeno al código es un bug, no un caso UX.
    if (e.statusCode == 400 && e.message == 'Invalid or expired code') {
      return const InvalidCodeFailure();
    }
    if (e.statusCode == 403) {
      if (e.message == 'Email is not verified') {
        return const EmailNotVerifiedFailure();
      }
      if (e.message == 'Account is suspended') {
        return const AccountSuspendedFailure();
      }
    }
    if (e.statusCode == 429) return const TooManyAttemptsFailure();
    return UnknownAuthFailure(e.message);
  }
}
