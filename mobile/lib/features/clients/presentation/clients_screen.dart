import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/client_model.dart';
import 'clients_state.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clientsProvider.notifier).loadClients();
    });
  }

  void _showAddClientDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final debtController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau Client (Crédit)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du client *',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numéro de téléphone',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: debtController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant de la dette (FCFA)',
                  prefixIcon: Icon(Icons.money_off),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final phone = phoneController.text.trim();
              final debt = double.tryParse(debtController.text.trim()) ?? 0.0;

              Navigator.pop(ctx);
              final ok = await ref.read(clientsProvider.notifier).addClient(
                    name,
                    phone: phone.isEmpty ? null : phone,
                    initialDebt: debt,
                  );
              if (mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Client enregistré avec succès')),
                );
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(ClientModel client) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remboursement : ${client.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dette actuelle : ${client.debtAmount.toStringAsFixed(0)} FCFA',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Montant remboursé (FCFA)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text.trim());
              if (amount == null || amount <= 0) return;

              Navigator.pop(ctx);
              final ok = await ref.read(clientsProvider.notifier).payDebt(client.id, amount);
              if (mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Remboursement de ${amount.toStringAsFixed(0)} FCFA validé !'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
            },
            child: const Text('Valider le paiement'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carnet de Dettes (Crédits)'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Ajouter un client',
            onPressed: _showAddClientDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(clientsProvider.notifier).loadClients(),
        child: state.isLoading && state.clients.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Bannière récapitulative du total dû
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE74C3C), Color(0xFFC0392B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE74C3C).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total des Crédits en Attente',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${state.totalDebts.toStringAsFixed(0)} FCFA',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${state.clients.where((c) => c.debtAmount > 0).length} client(s) endetté(s)',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                        const Icon(Icons.account_balance_wallet, color: Colors.white, size: 42),
                      ],
                    ),
                  ),

                  // Liste des clients
                  Expanded(
                    child: state.clients.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucun client enregistré pour l\'instant.\nAppuyez sur + pour ajouter un client à crédit.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: state.clients.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final client = state.clients[index];
                              final hasDebt = client.debtAmount > 0;

                              return Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: hasDebt
                                        ? Colors.redAccent.withValues(alpha: 0.3)
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: hasDebt
                                        ? Colors.redAccent.withValues(alpha: 0.1)
                                        : Colors.green.withValues(alpha: 0.1),
                                    child: Icon(
                                      Icons.person,
                                      color: hasDebt ? Colors.redAccent : Colors.green,
                                    ),
                                  ),
                                  title: Text(
                                    client.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: Text(
                                    client.phone ?? 'Pas de numéro',
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${client.debtAmount.toStringAsFixed(0)} FCFA',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: hasDebt ? Colors.redAccent : Colors.green,
                                        ),
                                      ),
                                      if (hasDebt)
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(50, 24),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () => _showPaymentDialog(client),
                                          child: const Text('Rembourser', style: TextStyle(fontSize: 12)),
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_add_client',
        onPressed: _showAddClientDialog,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau Client', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
