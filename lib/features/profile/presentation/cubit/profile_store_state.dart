import 'package:equatable/equatable.dart';

import '../../../store/domain/entities/store_info.dart';

/// Estado de "El local" (§030.1, solo presentación): el `StoreInfo`
/// mock. En integración lo trae GET /store/config completo vía
/// `GetStoreInfoUseCase` de la feature store — el abierto/cerrado en
/// vivo NO vive aquí: lo sigue resolviendo `StoreStatusCubit` del
/// shell (mismo dato real del chip del header).
class ProfileStoreState extends Equatable {
  const ProfileStoreState({required this.store});

  final StoreInfo store;

  ProfileStoreState copyWith({StoreInfo? store}) {
    return ProfileStoreState(store: store ?? this.store);
  }

  @override
  List<Object?> get props => [store];
}
