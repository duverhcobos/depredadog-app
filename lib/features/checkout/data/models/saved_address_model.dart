import '../../domain/entities/saved_address.dart';

/// SOLID (SRP): única clase que conoce el JSON de /addresses (GET y
/// POST, backend 014). Model extends Entity + factory fromJson —
/// convención del repo. `type` viaja como string 'home'|'work'|'other'.
class SavedAddressModel extends SavedAddress {
  const SavedAddressModel({
    required super.id,
    required super.label,
    required super.landmark,
    super.neighborhood,
    super.type,
  });

  factory SavedAddressModel.fromJson(Map<String, dynamic> json) {
    return SavedAddressModel(
      id: json['id'] as String,
      label: json['label'] as String,
      landmark: json['landmark'] as String,
      neighborhood: (json['neighborhood'] as String?) ?? '',
      type: _typeFromString(json['type'] as String?),
    );
  }

  static SavedAddressType _typeFromString(String? raw) => switch (raw) {
    'home' => SavedAddressType.home,
    'work' => SavedAddressType.work,
    _ => SavedAddressType.other,
  };
}
