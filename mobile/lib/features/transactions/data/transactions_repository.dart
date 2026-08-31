import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'transaction_model.dart';

class TransactionsRepository {
  final ApiClient _apiClient;

  TransactionsRepository(this._apiClient);

  Future<List<TransactionModel>> getTransactions() async {
    final response = await _apiClient.get(ApiEndpoints.transactions);
    final List<dynamic> data = response.data;
    return data.map((json) => TransactionModel.fromJson(json)).toList();
  }
}
