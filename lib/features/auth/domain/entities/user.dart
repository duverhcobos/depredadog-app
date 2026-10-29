import 'package:equatable/equatable.dart';

/// SOLID (SRP): representa al usuario autenticado — solo los campos que la
/// app usa hoy (MVP). El resto de UserResponseDto (phone, emailVerifiedAt,
/// referralCode, marketingOptIn, createdAt) se suma cuando una pantalla
/// real los necesite, sin romper este contrato.
class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.status,
  });

  final String id;
  final String email;
  final String firstName;
  final String? lastName;

  /// Valores del backend: 'customer' | 'admin'.
  final String role;

  /// Valores del backend: 'pending_verification' | 'active' | 'suspended'.
  final String status;

  @override
  List<Object?> get props => [id, email, firstName, lastName, role, status];
}
