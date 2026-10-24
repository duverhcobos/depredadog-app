/// Puerto de conectividad. Los repositories lo consultan antes de llamadas
/// remotas (regla 5 SOLID — el impl concreto es intercambiable).
abstract class INetworkInfo {
  Future<bool> get isConnected;
}
