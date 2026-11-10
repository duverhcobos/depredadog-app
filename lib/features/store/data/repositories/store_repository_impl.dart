import 'package:dartz/dartz.dart';

import '../../../../core/network/exceptions/network_exception.dart';
import '../../../../core/network/interfaces/i_network_info.dart';
import '../../domain/entities/store_open_state.dart';
import '../../domain/failures/store_failure.dart';
import '../../domain/repositories/i_store_repository.dart';
import '../datasources/interfaces/i_store_remote_datasource.dart';

/// SOLID (SRP): datasource + conectividad; traduce NetworkException
/// → StoreFailure — mismo `_guard` mínimo de OrdersRepositoryImpl.
/// La UI nunca ve excepciones crudas (§029).
class StoreRepositoryImpl implements IStoreRepository {
  const StoreRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  final IStoreRemoteDataSource remoteDataSource;
  final INetworkInfo networkInfo;

  @override
  Future<Either<StoreFailure, StoreOpenState>> getOpenState() async {
    if (!await networkInfo.isConnected) {
      return const Left(StoreFetchFailure('Sin conexión'));
    }
    try {
      return Right(await remoteDataSource.fetchOpenState());
    } on NetworkException catch (e) {
      return Left(StoreFetchFailure(e.message));
    } catch (e) {
      return Left(StoreFetchFailure(e.toString()));
    }
  }
}
