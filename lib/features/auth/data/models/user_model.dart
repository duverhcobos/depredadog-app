import '../../domain/entities/user.dart';

/// SOLID (SRP): única clase que conoce el JSON de UserResponseDto.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.firstName,
    required super.lastName,
    required super.role,
    required super.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    email: json['email'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String?,
    role: json['role'] as String,
    status: json['status'] as String,
  );
}
