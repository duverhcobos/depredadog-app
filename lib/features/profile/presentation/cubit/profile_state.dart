import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/user.dart';

/// Estado del tab Perfil (§030 + §030.1, solo presentación): usuario
/// mock + código de referido + puntos/referidos de la tarjeta de
/// fidelidad. El conteo de direcciones del subtítulo del menú lo lee
/// la pantalla directamente del ProfileAddressesCubit (misma instancia
/// que la lista — nunca diverge). En integración `user` viene de
/// GET/PATCH /auth/me (fresco al abrir el tab, con
/// AuthSession.currentUser como primer render); loyalty es módulo
/// backend futuro — los campos ya quedan con la forma real.
class ProfileState extends Equatable {
  const ProfileState({
    required this.user,
    this.referralCode,
    this.loyaltyPoints = 0,
    this.referredCount = 0,
    this.loggingOut = false,
  });

  /// Usuario autenticado — null solo antes del primer render (fase 1
  /// siempre tiene el mock).
  final User? user;

  /// Código de referido propio — mock en fase 1; en fase 2 lo trae
  /// GET /auth/me (la entidad User gana el campo en ese ciclo).
  final String? referralCode;

  /// Puntos de fidelidad — headline de la loyalty card (mock 120;
  /// módulo loyalty del backend aún no existe).
  final int loyaltyPoints;

  /// Personas que se sumaron con el código del usuario (mock 2).
  final int referredCount;

  /// Spinner del diálogo de logout — fase 1 no lo usa (acción mock).
  final bool loggingOut;

  ProfileState copyWith({
    User? user,
    String? referralCode,
    int? loyaltyPoints,
    int? referredCount,
    bool? loggingOut,
  }) {
    return ProfileState(
      user: user ?? this.user,
      referralCode: referralCode ?? this.referralCode,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      referredCount: referredCount ?? this.referredCount,
      loggingOut: loggingOut ?? this.loggingOut,
    );
  }

  @override
  List<Object?> get props => [
    user,
    referralCode,
    loyaltyPoints,
    referredCount,
    loggingOut,
  ];
}
