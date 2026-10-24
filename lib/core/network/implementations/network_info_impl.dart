import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../interfaces/i_network_info.dart';

/// ISP: el cliente solo ve `isConnected`; la lib de chequeo es detalle interno.
class NetworkInfoImpl implements INetworkInfo {
  const NetworkInfoImpl(this._checker);

  final InternetConnectionChecker _checker;

  @override
  Future<bool> get isConnected => _checker.hasConnection;
}
