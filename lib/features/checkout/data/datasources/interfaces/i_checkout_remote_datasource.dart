import '../../models/checkout_store_model.dart';
import '../../models/placed_order_model.dart';
import '../../models/saved_address_model.dart';

/// SOLID (DIP): puerto HTTP del checkout — devuelve models o lanza
/// NetworkException; los callers nunca ven Dio.
abstract class ICheckoutRemoteDataSource {
  /// GET /addresses — Bearer lo adjunta el AuthInterceptor.
  Future<List<SavedAddressModel>> fetchAddresses();

  /// GET /store/config.
  Future<CheckoutStoreModel> fetchStoreConfig();

  /// POST /addresses — el body lo arma el repository (label/landmark/
  /// neighborhood?/type); responde 201 con la dirección creada.
  Future<SavedAddressModel> createAddress(Map<String, dynamic> body);

  /// POST /orders — confirma el pedido (§026). Devuelve el modelo de
  /// la orden creada; errores → NetworkException cruda (los traduce
  /// el repository).
  Future<PlacedOrderModel> createOrder(Map<String, dynamic> body);
}
