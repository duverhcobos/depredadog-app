import 'package:equatable/equatable.dart';

/// El splash solo bifurca éxito/fracaso — no le interesa el motivo del
/// Left (la semántica de limpiar/conservar tokens vive en el repositorio).
enum SplashStatus { restoring, restored, guest }

class SplashState extends Equatable {
  const SplashState({this.status = SplashStatus.restoring});

  final SplashStatus status;

  @override
  List<Object?> get props => [status];
}
