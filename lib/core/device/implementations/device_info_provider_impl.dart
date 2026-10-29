import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../interfaces/i_device_info_provider.dart';

/// SOLID (SRP): única clase que toca device_info_plus/dart:io Platform.
class DeviceInfoProviderImpl implements IDeviceInfoProvider {
  DeviceInfoProviderImpl() : _plugin = DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;

  @override
  Future<String?> fingerprint() async {
    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        return info.id; // androidId — ya pseudónimo, MaxLength(255) sobrado
      }
      if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        return info.identifierForVendor; // ID por vendor de Apple
      }
    } catch (_) {
      // Campo opcional en el backend — cualquier fallo de la plataforma
      // no debe bloquear el login.
    }
    return null;
  }

  @override
  String? get platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return null;
  }
}
