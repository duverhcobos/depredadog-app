import '../../domain/entities/checkout_store.dart';

/// SOLID (SRP): única clase que conoce el JSON de GET /store/config
/// (backend 013). Los nullables del contrato viajan honestos —
/// `address`/`logoUrl`/`minDeliveryOrder` pueden ser null.
class CheckoutStoreModel extends CheckoutStore {
  const CheckoutStoreModel({
    required super.name,
    required super.address,
    required super.deliveryFee,
    required super.isOpen,
    super.minDeliveryOrder,
    super.logoUrl,
  });

  factory CheckoutStoreModel.fromJson(Map<String, dynamic> json) {
    return CheckoutStoreModel(
      name: json['name'] as String,
      address: (json['address'] as String?) ?? '',
      deliveryFee: (json['deliveryFee'] as num).toInt(),
      isOpen: json['isOpen'] as bool,
      minDeliveryOrder: (json['minDeliveryOrder'] as num?)?.toInt(),
      logoUrl: json['logoUrl'] as String?,
    );
  }
}
