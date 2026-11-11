import 'package:equatable/equatable.dart';

/// Una fila del horario semanal del local — espejo de
/// `DayHoursResponseDto` (backend 013): `dayOfWeek` 0-6 con la
/// convención JS del backend (0 = domingo … 6 = sábado), `opensAt` /
/// `closesAt` en 'HH:MM' hora local del negocio.
class StoreDayHours extends Equatable {
  const StoreDayHours({
    required this.dayOfWeek,
    required this.opensAt,
    required this.closesAt,
    this.isClosed = false,
  });

  /// 0 = domingo … 6 = sábado (Date.getDay() del backend — para hoy,
  /// comparar con `DateTime.now().weekday % 7`).
  final int dayOfWeek;

  /// 'HH:MM' hora local del negocio.
  final String opensAt;
  final String closesAt;

  /// El local no abre este día — la fila se muestra "Cerrado".
  final bool isClosed;

  @override
  List<Object?> get props => [dayOfWeek, opensAt, closesAt, isClosed];
}

/// Datos públicos del local (§030.1) — espejo de
/// `StoreConfigResponseDto` para la pantalla "El local" del perfil.
/// Solo los campos de vitrina: el fee/mínimo los consume el checkout
/// (`CheckoutStore`), `isOpen`/`today` ya los resuelve
/// `StoreStatusCubit` en vivo — no se duplican aquí.
class StoreInfo extends Equatable {
  const StoreInfo({
    required this.name,
    this.phone,
    this.address,
    this.logoUrl,
    this.weeklyHours = const [],
  });

  final String name;
  final String? phone;
  final String? address;
  final String? logoUrl;

  /// Las 7 filas del horario — el orden de la lista es el orden de
  /// pintado (el mock lo arma lunes→domingo).
  final List<StoreDayHours> weeklyHours;

  @override
  List<Object?> get props => [name, phone, address, logoUrl, weeklyHours];
}
