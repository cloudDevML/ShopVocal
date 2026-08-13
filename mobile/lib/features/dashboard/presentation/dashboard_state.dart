import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/dashboard_models.dart';
import '../data/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DashboardRepository(apiClient);
});

class DashboardState {
  final FinancialSummaryModel? summary;
  final List<TransactionModel> transactions;
  final bool isLoading;
  final String? errorMessage;

  DashboardState({
    this.summary,
    this.transactions = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  DashboardState copyWith({
    FinancialSummaryModel? summary,
    List<TransactionModel>? transactions,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DashboardState(
      summary: summary ?? this.summary,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final DashboardRepository _repository;

  DashboardNotifier(this._repository) : super(DashboardState());

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final summary = await _repository.fetchSummary();
      final transactions = await _repository.fetchTransactions();
      // Trier par date décroissante
      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = DashboardState(
        summary: summary,
        transactions: transactions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final repository = ref.watch(dashboardRepositoryProvider);
  return DashboardNotifier(repository);
});
