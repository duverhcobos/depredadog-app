import '../../../../../core/network/interfaces/i_network_service.dart';
import '../../models/checkout_store_model.dart';
import '../../models/placed_order_model.dart';
import '../../models/saved_address_model.dart';
import '../interfaces/i_checkout_remote_datasource.dart';

/// SOLID (SRP): solo llama los endpoints y parsea — el Bearer lo pone
/// el AuthInterceptor, los errores los traduce el repository.
class CheckoutRemoteDataSourceImpl implements ICheckoutRemoteDataSource {
  const CheckoutRemoteDataSourceImpl({required this._networkService});

  final INetworkService _networkService;

  @override
  Future<List<SavedAddressModel>> fetchAddresses() async {
    final response = await _networkService.get('/addresses');
    return (response as List<dynamic>)
        .map((a) => SavedAddressModel.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CheckoutStoreModel> fetchStoreConfig() async {
    final response = await _networkService.get('/store/config');
    return CheckoutStoreModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<SavedAddressModel> createAddress(Map<String, dynamic> body) async {
    final response = await _networkService.post('/addresses', body: body);
    return SavedAddressModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<PlacedOrderModel> createOrder(Map<String, dynamic> body) async {
    final response = await _networkService.post('/orders', body: body);
    return PlacedOrderModel.fromJson(response as Map<String, dynamic>);
  }
}
