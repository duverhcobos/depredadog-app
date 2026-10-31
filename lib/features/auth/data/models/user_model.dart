import '../../domain/entities/user.dart';

/// SOLID (SRP): única clase que conoce el JSON de UserResponseDto
/// (contrato post-split LatAm: secondName/firstLastName/secondLastName —
/// ya no existe `lastName`; los opcionales llegan null o ausentes).
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.firstName,
    super.secondName,
    required super.firstLastName,
    super.secondLastName,
    required super.role,
    required super.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    email: json['email'] as String,
    firstName: json['firstName'] as String,
    secondName: json['secondName'] as String?,
    firstLastName: json['firstLastName'] as String,
    secondLastName: json['secondLastName'] as String?,
    role: json['role'] as String,
    status: json['status'] as String,
  );
}
