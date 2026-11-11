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
    super.isDefault,
  });

  factory SavedAddressModel.fromJson(Map<String, dynamic> json) {
    return SavedAddressModel(
      id: json['id'] as String,
      label: json['label'] as String,
      landmark: json['landmark'] as String,
      neighborhood: (json['neighborhood'] as String?) ?? '',
      type: _typeFromString(json['type'] as String?),
      // §030 — el recurso ya trae el flag; el checkout lo ignora y
      // profile lo necesita para el badge "Predeterminada". Aditivo:
      // ausente → false (dirección no-default).
      isDefault: (json['isDefault'] as bool?) ?? false,
    );
  }

  static SavedAddressType _typeFromString(String? raw) => switch (raw) {
    'home' => SavedAddressType.home,
    'work' => SavedAddressType.work,
    _ => SavedAddressType.other,
  };
}
