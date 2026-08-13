import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/inventory_repository.dart';
import '../data/product_model.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InventoryRepository(apiClient);
});

class InventoryState {
  final List<ProductModel> products;
  final List<ProductModel> lowStockAlerts;
  final bool isLoading;
  final String? errorMessage;

  InventoryState({
    this.products = const [],
    this.lowStockAlerts = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  InventoryState copyWith({
    List<ProductModel>? products,
    List<ProductModel>? lowStockAlerts,
    bool? isLoading,
    String? errorMessage,
  }) {
    return InventoryState(
      products: products ?? this.products,
      lowStockAlerts: lowStockAlerts ?? this.lowStockAlerts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class InventoryNotifier extends StateNotifier<InventoryState> {
  final InventoryRepository _repository;

  InventoryNotifier(this._repository) : super(InventoryState());

  Future<void> loadInventory() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final products = await _repository.fetchProducts();
      final alerts = await _repository.fetchLowStockAlerts();
      state = InventoryState(
        products: products,
        lowStockAlerts: alerts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> addProduct({
    required String name,
    required double quantity,
    required double unitPrice,
    double? costPrice,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final newProduct = await _repository.createProduct(
        name: name,
        quantity: quantity,
        unitPrice: unitPrice,
        costPrice: costPrice,
      );
      state = state.copyWith(
        products: [...state.products, newProduct],
        isLoading: false,
      );
      // Re-load inventory to sync alerts
      loadInventory();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final inventoryProvider = StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  final repository = ref.watch(inventoryRepositoryProvider);
  return InventoryNotifier(repository);
});
