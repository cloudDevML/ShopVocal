import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/transaction_model.dart';
import 'transactions_state.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionsProvider.notifier).loadTransactions();
    });
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'SALE':
        return AppTheme.successColor;
      case 'PURCHASE':
        return Colors.blueAccent;
      case 'EXPENSE':
        return Colors.deepOrangeAccent;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'SALE':
        return Icons.arrow_upward;
      case 'PURCHASE':
        return Icons.shopping_bag_outlined;
      case 'EXPENSE':
        return Icons.arrow_downward;
      default:
        return Icons.swap_horiz;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'SALE':
        return 'Vente';
      case 'PURCHASE':
        return 'Achat Stock';
      case 'EXPENSE':
        return 'Dépense';
      default:
        return type;
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionsProvider);
    final filtered = state.filteredTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal des Transactions'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filtres par type de transaction
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'Toutes (${state.transactions.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('SALE', 'Ventes'),
                  const SizedBox(width: 8),
                  _buildFilterChip('PURCHASE', 'Achats'),
                  const SizedBox(width: 8),
                  _buildFilterChip('EXPENSE', 'Dépenses'),
                ],
              ),
            ),
          ),

          // Liste des transactions
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(transactionsProvider.notifier).loadTransactions(),
              child: state.isLoading && state.transactions.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucune transaction trouvée.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final txn = filtered[index];
                            final color = _getTypeColor(txn.type);
                            final icon = _getTypeIcon(txn.type);
                            final label = _getTypeLabel(txn.type);

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: color.withValues(alpha: 0.2)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: color.withValues(alpha: 0.15),
                                  child: Icon(icon, color: color),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${txn.amount.toStringAsFixed(0)} FCFA',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        txn.description ?? 'Sans description',
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          if (txn.quantity != null)
                                            Text(
                                              'Qté : ${txn.quantity}',
                                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                                            )
                                          else
                                            const SizedBox.shrink(),
                                          Text(
                                            _formatDate(txn.createdAt),
                                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final currentFilter = ref.watch(transactionsProvider).selectedFilter;
    final isSelected = currentFilter == filterKey;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        ref.read(transactionsProvider.notifier).setFilter(filterKey);
      },
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
