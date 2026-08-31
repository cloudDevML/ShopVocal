import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'client_model.dart';

class ClientsRepository {
  final ApiClient _apiClient;

  ClientsRepository(this._apiClient);

  Future<List<ClientModel>> getClients() async {
    final response = await _apiClient.get(ApiEndpoints.clients);
    final List<dynamic> data = response.data;
    return data.map((json) => ClientModel.fromJson(json)).toList();
  }

  Future<ClientModel> createClient(String name, {String? phone, double debtAmount = 0.0}) async {
    final response = await _apiClient.post(
      ApiEndpoints.clients,
      data: {
        'name': name,
        'phone': phone,
        'debt_amount': debtAmount,
      },
    );
    return ClientModel.fromJson(response.data);
  }

  Future<void> payDebt(int clientId, double amountPaid) async {
    await _apiClient.put(
      '${ApiEndpoints.clients}/$clientId/pay',
      queryParameters: {'amount_paid': amountPaid},
    );
  }
}
