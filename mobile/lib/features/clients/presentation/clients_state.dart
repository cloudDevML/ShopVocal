import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/client_model.dart';
import '../data/clients_repository.dart';

final clientsRepositoryProvider = Provider<ClientsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ClientsRepository(apiClient);
});

class ClientsState {
  final bool isLoading;
  final List<ClientModel> clients;
  final String? errorMessage;

  ClientsState({
    this.isLoading = false,
    this.clients = const [],
    this.errorMessage,
  });

  double get totalDebts => clients.fold(0.0, (sum, c) => sum + c.debtAmount);

  ClientsState copyWith({
    bool? isLoading,
    List<ClientModel>? clients,
    String? errorMessage,
  }) {
    return ClientsState(
      isLoading: isLoading ?? this.isLoading,
      clients: clients ?? this.clients,
      errorMessage: errorMessage,
    );
  }
}

class ClientsNotifier extends StateNotifier<ClientsState> {
  final ClientsRepository _repository;

  ClientsNotifier(this._repository) : super(ClientsState());

  Future<void> loadClients() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository.getClients();
      state = state.copyWith(isLoading: false, clients: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> addClient(String name, {String? phone, double initialDebt = 0.0}) async {
    try {
      final client = await _repository.createClient(name, phone: phone, debtAmount: initialDebt);
      state = state.copyWith(clients: [...state.clients, client]);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> payDebt(int clientId, double amount) async {
    try {
      await _repository.payDebt(clientId, amount);
      await loadClients();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }
}

final clientsProvider = StateNotifierProvider<ClientsNotifier, ClientsState>((ref) {
  final repo = ref.watch(clientsRepositoryProvider);
  return ClientsNotifier(repo);
});
