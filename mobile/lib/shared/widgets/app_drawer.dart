import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/clients/presentation/clients_screen.dart';
import '../../features/transactions/presentation/transactions_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

class AppDrawer extends ConsumerWidget {
  final int currentTabIndex;
  final Function(int)? onTabSelected;

  const AppDrawer({
    super.key,
    this.currentTabIndex = 0,
    this.onTabSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    final profile = authState.userProfile;
    final isDark = themeMode == ThemeMode.dark;

    return Drawer(
      child: Column(
        children: [
          // En-tête commerçant / boutique
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, Color(0xFF4A44B5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: const Icon(Icons.storefront, size: 40, color: AppTheme.primaryColor),
            ),
            accountName: Text(
              profile?.fullName ?? 'Ma Boutique',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            accountEmail: Row(
              children: [
                const Icon(Icons.phone_android, size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  profile?.phoneNumber ?? '',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),

          // Liens de navigation
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: const Text('Comptabilité & Bilan'),
                  selected: currentTabIndex == 0,
                  selectedColor: AppTheme.primaryColor,
                  selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  onTap: () {
                    Navigator.pop(context);
                    if (onTabSelected != null) {
                      onTabSelected!(0);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Gestion du Stock'),
                  selected: currentTabIndex == 1,
                  selectedColor: AppTheme.primaryColor,
                  selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  onTap: () {
                    Navigator.pop(context);
                    if (onTabSelected != null) {
                      onTabSelected!(1);
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined, color: Colors.redAccent),
                  title: const Text('Carnet de Dettes (Crédits)'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Clients',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ClientsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined, color: Colors.blueAccent),
                  title: const Text('Journal des Transactions'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                    );
                  },
                ),
                const Divider(),
                // Switch rapide pour mode sombre/clair
                SwitchListTile(
                  secondary: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: isDark ? Colors.amber : Colors.deepPurpleAccent,
                  ),
                  title: const Text('Mode Sombre'),
                  value: isDark,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (val) {
                    ref.read(themeModeProvider.notifier).setThemeMode(
                          val ? ThemeMode.dark : ThemeMode.light,
                        );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Paramètres du Compte'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          // Déconnexion en bas
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.errorColor),
            title: const Text(
              'Déconnexion',
              style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              final authNotifier = ref.read(authProvider.notifier);
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Déconnexion'),
                  content: const Text('Voulez-vous fermer votre session commerçant ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annuler'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await authNotifier.logout();
                      },
                      child: const Text('Se déconnecter'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
