import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import 'dashboard_state.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradientColors,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Icon(icon, color: Colors.white, size: 36),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0)} FCFA';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final summary = state.summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma Boutique'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(dashboardProvider.notifier).loadDashboard();
        },
        child: state.isLoading && summary == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre section KPIs
                    const Text(
                      'Synthèse Financière',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                    ),
                    const SizedBox(height: 12),

                    // Grille des KPIs
                    _buildKpiCard(
                      title: 'Chiffre d\'Affaires (Ventes)',
                      value: _formatCurrency(summary?.turnover ?? 0.0),
                      icon: Icons.trending_up,
                      gradientColors: [const Color(0xFF2ECC71), const Color(0xFF27AE60)],
                      context: context,
                    ),
                    const SizedBox(height: 12),
                    _buildKpiCard(
                      title: 'Achats Stock & Dépenses',
                      value: _formatCurrency((summary?.stockPurchases ?? 0.0) + (summary?.ancillaryExpenses ?? 0.0)),
                      icon: Icons.trending_down,
                      gradientColors: [const Color(0xFFFF6B6B), const Color(0xFFEE5253)],
                      context: context,
                    ),
                    const SizedBox(height: 12),
                    _buildKpiCard(
                      title: 'Bénéfice Net Estimé',
                      value: _formatCurrency(summary?.netProfit ?? 0.0),
                      icon: Icons.account_balance_wallet,
                      gradientColors: [const Color(0xFF6C63FF), const Color(0xFF574BDF)],
                      context: context,
                    ),
                    const SizedBox(height: 24),

                    // Section Historique Transactions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Transactions Récentes',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                        ),
                        if (state.isLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (state.transactions.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              'Aucune transaction enregistrée.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.transactions.length,
                        itemBuilder: (context, index) {
                          final txn = state.transactions[index];
                          final isSale = txn.type == 'SALE';
                          final isPurchase = txn.type == 'PURCHASE';

                          IconData iconData = Icons.payment;
                          Color iconColor = Colors.grey;
                          if (isSale) {
                            iconData = Icons.arrow_downward;
                            iconColor = AppTheme.successColor;
                          } else if (isPurchase) {
                            iconData = Icons.arrow_upward;
                            iconColor = Colors.orange;
                          } else {
                            iconData = Icons.remove_shopping_cart;
                            iconColor = AppTheme.errorColor;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: iconColor.withValues(alpha: 0.1),
                                child: Icon(iconData, color: iconColor),
                              ),
                              title: Text(
                                txn.description ?? (isSale ? 'Vente' : isPurchase ? 'Achat de stock' : 'Dépense'),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                '${txn.createdAt.day}/${txn.createdAt.month}/${txn.createdAt.year} ${txn.createdAt.hour}:${txn.createdAt.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              trailing: Text(
                                '${isSale ? "+" : "-"}${txn.amount.toStringAsFixed(0)} F',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSale ? AppTheme.successColor : AppTheme.errorColor,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
