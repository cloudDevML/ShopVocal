import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../settings/presentation/settings_screen.dart';
import 'inventory_state.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  final Function(int)? onTabSelected;

  const InventoryScreen({super.key, this.onTabSelected});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final salePriceController = TextEditingController();
    final costPriceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ajouter un Produit'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nom de l\'article'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: 'Quantité initiale'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || double.tryParse(v) == null ? 'Nombre invalide' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: salePriceController,
                    decoration: const InputDecoration(labelText: 'Prix de vente (FCFA)'),
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || double.tryParse(v) == null ? 'Prix invalide' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: costPriceController,
                    decoration: const InputDecoration(labelText: 'Prix d\'achat unitaire (Optionnel)'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                
                final success = await ref.read(inventoryProvider.notifier).addProduct(
                  name: nameController.text.trim(),
                  quantity: double.parse(quantityController.text),
                  unitPrice: double.parse(salePriceController.text),
                  costPrice: double.tryParse(costPriceController.text),
                );

                if (context.mounted) {
                  if (success) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Produit ajouté au stock !'), backgroundColor: AppTheme.successColor),
                    );
                  }
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);

    // Filtrer les produits localement selon la barre de recherche
    final filteredProducts = state.products.where((p) {
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion du Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser le stock',
            onPressed: () {
              ref.read(inventoryProvider.notifier).loadInventory();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres du compte',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      drawer: AppDrawer(
        currentTabIndex: 1,
        onTabSelected: widget.onTabSelected,
      ),
      body: state.isLoading && state.products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Barre de recherche
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un produit...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Messages d'erreur
                  if (state.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(color: AppTheme.errorColor),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Liste des produits
                  Expanded(
                    child: filteredProducts.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucun produit trouvé dans le stock.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              final isLowStock = product.quantity <= product.minStockAlert;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isLowStock 
                                        ? AppTheme.errorColor.withValues(alpha: 0.1) 
                                        : AppTheme.primaryColor.withValues(alpha: 0.1),
                                    child: Icon(
                                      Icons.inventory_2_outlined,
                                      color: isLowStock ? AppTheme.errorColor : AppTheme.primaryColor,
                                    ),
                                  ),
                                  title: Text(
                                    product.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: Text(
                                    'Prix Vente : ${product.unitPrice.toStringAsFixed(0)} FCFA\n'
                                    'Prix Achat : ${product.costPrice.toStringAsFixed(0)} FCFA',
                                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${product.quantity.toStringAsFixed(0)} U',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: isLowStock ? AppTheme.errorColor : AppTheme.successColor,
                                        ),
                                      ),
                                      if (isLowStock)
                                        const Text(
                                          'Stock Bas !',
                                          style: TextStyle(color: AppTheme.errorColor, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
