/// Puerto de información del dispositivo — hoy solo lo usa auth
/// (deviceFingerprint/platform de /auth/login), pero vive en core/ porque
/// no es un concepto propio de esa feature.
abstract class IDeviceInfoProvider {
  /// Identificador estable del dispositivo para ligar la sesión
  /// (androidId / identifierForVendor). `null` si no se pudo obtener —
  /// el campo es opcional en el backend.
  Future<String?> fingerprint();

  /// 'android' | 'ios' | null en cualquier otra plataforma.
  String? get platform;
}
