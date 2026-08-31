import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/transaction_model.dart';
import '../data/transactions_repository.dart';

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TransactionsRepository(apiClient);
});

class TransactionsState {
  final bool isLoading;
  final List<TransactionModel> transactions;
  final String? errorMessage;
  final String selectedFilter; // 'ALL', 'SALE', 'PURCHASE', 'EXPENSE'

  TransactionsState({
    this.isLoading = false,
    this.transactions = const [],
    this.errorMessage,
    this.selectedFilter = 'ALL',
  });

  List<TransactionModel> get filteredTransactions {
    if (selectedFilter == 'ALL') return transactions;
    return transactions.where((t) => t.type == selectedFilter).toList();
  }

  TransactionsState copyWith({
    bool? isLoading,
    List<TransactionModel>? transactions,
    String? errorMessage,
    String? selectedFilter,
  }) {
    return TransactionsState(
      isLoading: isLoading ?? this.isLoading,
      transactions: transactions ?? this.transactions,
      errorMessage: errorMessage,
      selectedFilter: selectedFilter ?? this.selectedFilter,
    );
  }
}

class TransactionsNotifier extends StateNotifier<TransactionsState> {
  final TransactionsRepository _repository;

  TransactionsNotifier(this._repository) : super(TransactionsState());

  Future<void> loadTransactions() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository.getTransactions();
      // Trier par ID descendant (les plus récentes en premier)
      list.sort((a, b) => b.id.compareTo(a.id));
      state = state.copyWith(isLoading: false, transactions: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }
}

final transactionsProvider = StateNotifierProvider<TransactionsNotifier, TransactionsState>((ref) {
  final repo = ref.watch(transactionsRepositoryProvider);
  return TransactionsNotifier(repo);
});
