import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'dashboard_models.dart';

class DashboardRepository {
  final ApiClient _apiClient;

  DashboardRepository(this._apiClient);

  Future<FinancialSummaryModel> fetchSummary() async {
    final response = await _apiClient.get(ApiEndpoints.financialSummary);
    return FinancialSummaryModel.fromJson(response.data);
  }

  Future<List<TransactionModel>> fetchTransactions() async {
    final response = await _apiClient.get(ApiEndpoints.transactions);
    final List list = response.data;
    return list.map((item) => TransactionModel.fromJson(item)).toList();
  }
}
