import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/presentation/auth_state.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _showEditProfileDialog() {
    final authState = ref.read(authProvider);
    final nameController = TextEditingController(text: authState.userProfile?.fullName ?? '');
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le profil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom ou Nom de la Boutique',
                  prefixIcon: Icon(Icons.store),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nouveau mot de passe (optionnel)',
                  prefixIcon: Icon(Icons.lock_outline),
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
              final newName = nameController.text.trim();
              final newPwd = passwordController.text.trim();

              Navigator.pop(ctx);
              final success = await ref.read(authProvider.notifier).updateProfile(
                    fullName: newName.isEmpty ? null : newName,
                    password: newPwd.isEmpty ? null : newPwd,
                  );
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profil mis à jour avec succès'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmDialog() {
    final authNotifier = ref.read(authProvider.notifier);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter de votre boutique ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.popUntil(context, (route) => route.isFirst);
              await authNotifier.logout();
            },
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  void _showVoiceHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mic, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Exemples vocaux IA'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Parlez naturellement en français. L\'intelligence artificielle extrait automatiquement le montant, le produit, la quantité et le client.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              SizedBox(height: 16),
              _HelpItem(
                icon: Icons.point_of_sale,
                color: Colors.green,
                title: 'Enregistrer une vente :',
                phrase: '"J\'ai vendu 3 Coca-Cola pour 1500 FCFA"',
              ),
              SizedBox(height: 12),
              _HelpItem(
                icon: Icons.person_add,
                color: Colors.orange,
                title: 'Vente à crédit (ardoise client) :',
                phrase: '"Vente 2 paquets de sucre à Aminata pour 1600 FCFA"',
              ),
              SizedBox(height: 12),
              _HelpItem(
                icon: Icons.add_shopping_cart,
                color: Colors.blue,
                title: 'Achat de stock marchandise :',
                phrase: '"Achat de 50 kg de riz à 25000 FCFA"',
              ),
              SizedBox(height: 12),
              _HelpItem(
                icon: Icons.money_off,
                color: Colors.deepOrange,
                title: 'Dépense de boutique :',
                phrase: '"Dépense loyer boutique 80000 francs"',
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    final profile = authState.userProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Carte profil utilisateur
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                        child: const Icon(Icons.store, size: 36, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.fullName ?? 'Ma Boutique',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile?.phoneNumber ?? '',
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Boutique Active',
                                style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                        tooltip: 'Modifier les informations',
                        onPressed: _showEditProfileDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Section Apparence / Thème
          const Text(
            'Apparence & Affichage',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Row(
                    children: [
                      Icon(Icons.brightness_auto, size: 20),
                      SizedBox(width: 12),
                      Text('Système (automatique)'),
                    ],
                  ),
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (mode) {
                    if (mode != null) ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  },
                ),
                const Divider(height: 1),
                RadioListTile<ThemeMode>(
                  title: const Row(
                    children: [
                      Icon(Icons.light_mode, size: 20, color: Colors.amber),
                      SizedBox(width: 12),
                      Text('Mode Clair'),
                    ],
                  ),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (mode) {
                    if (mode != null) ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  },
                ),
                const Divider(height: 1),
                RadioListTile<ThemeMode>(
                  title: const Row(
                    children: [
                      Icon(Icons.dark_mode, size: 20, color: Colors.deepPurpleAccent),
                      SizedBox(width: 12),
                      Text('Mode Sombre'),
                    ],
                  ),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (mode) {
                    if (mode != null) ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section Aide & Assistant Vocal
          const Text(
            'Aide & Outils',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.record_voice_over_outlined, color: AppTheme.primaryColor),
                  title: const Text('Guide vocal de l\'Assistant IA'),
                  subtitle: const Text('Voir des exemples de phrases à dicter'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showVoiceHelpDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
                  title: const Text('Version de l\'application'),
                  subtitle: const Text('v1.0.0 (FastAPI + Flutter + IA Fallback)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section Déconnexion
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.errorColor),
              title: const Text(
                'Se déconnecter',
                style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Fermer la session actuelle de la boutique'),
              onTap: _showLogoutConfirmDialog,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String phrase;

  const _HelpItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.phrase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                const SizedBox(height: 2),
                Text(phrase, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
