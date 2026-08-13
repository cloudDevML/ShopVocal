import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'product_model.dart';

class InventoryRepository {
  final ApiClient _apiClient;

  InventoryRepository(this._apiClient);

  Future<List<ProductModel>> fetchProducts() async {
    final response = await _apiClient.get(ApiEndpoints.products);
    final List list = response.data;
    return list.map((item) => ProductModel.fromJson(item)).toList();
  }

  Future<List<ProductModel>> fetchLowStockAlerts() async {
    final response = await _apiClient.get(ApiEndpoints.productAlerts);
    final List list = response.data;
    return list.map((item) => ProductModel.fromJson(item)).toList();
  }

  Future<ProductModel> createProduct({
    required String name,
    required double quantity,
    required double unitPrice,
    double? costPrice,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.products,
      data: {
        'name': name,
        'quantity': quantity,
        'unit_price': unitPrice,
        'cost_price': costPrice ?? 0.0,
      },
    );
    return ProductModel.fromJson(response.data);
  }
}
