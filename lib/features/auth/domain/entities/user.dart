import 'package:equatable/equatable.dart';

/// SOLID (SRP): representa al usuario autenticado — solo los campos que la
/// app usa hoy (MVP). El resto de UserResponseDto (emailVerifiedAt,
/// referralCode, marketingOptIn, createdAt) se suma cuando una pantalla
/// real los necesite, sin romper este contrato.
///
/// Nombres según el split LatAm del backend (propuesta backend 004):
/// `firstLastName` es requerido; `secondName`/`secondLastName` llegan
/// `null` cuando el usuario no los diligenció — ya no existe `lastName`.
class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.firstName,
    this.secondName,
    required this.firstLastName,
    this.secondLastName,
    this.phone,
    required this.role,
    required this.status,
  });

  final String id;
  final String email;
  final String firstName;
  final String? secondName;
  final String firstLastName;
  final String? secondLastName;

  /// Celular opcional del registro (10 dígitos, 3XX XXX XXXX) — checkout
  /// lo prellena como celular Nequi (§022). Null si no lo diligenció.
  final String? phone;

  /// Valores del backend: 'customer' | 'admin'.
  final String role;

  /// Valores del backend: 'pending_verification' | 'active' | 'suspended'.
  final String status;

  @override
  List<Object?> get props => [
    id,
    email,
    firstName,
    secondName,
    firstLastName,
    secondLastName,
    phone,
    role,
    status,
  ];
}
