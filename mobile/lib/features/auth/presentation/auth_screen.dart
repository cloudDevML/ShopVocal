import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import 'auth_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit(WidgetRef ref) {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (_isLogin) {
      ref.read(authProvider.notifier).login(phone, password);
    } else {
      ref.read(authProvider.notifier).register(phone, password, name.isEmpty ? null : name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Icône Premium
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      size: 72,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Titre
                  Text(
                    _isLogin ? 'Connexion Commerçant' : 'Création de Compte',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin 
                        ? 'Gérez votre boutique par la voix en un instant' 
                        : 'Commencez à suivre vos ventes et stocks aujourd\'hui',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 32),

                  // Champ Nom Complet (uniquement à l'inscription)
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet ou Boutique',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (!_isLogin && (value == null || value.trim().isEmpty)) {
                          return 'Veuillez saisir votre nom ou celui de votre boutique';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Champ Téléphone
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Numéro de téléphone',
                      hintText: 'Ex: +221770000000',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Veuillez saisir votre numéro de téléphone';
                      }
                      if (value.length < 8) {
                        return 'Numéro de téléphone invalide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Champ Mot de passe
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez saisir un mot de passe';
                      }
                      if (value.length < 6) {
                        return 'Le mot de passe doit faire au moins 6 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Bouton de soumission
                  Consumer(
                    builder: (context, ref, child) {
                      final state = ref.watch(authProvider);

                      if (state.status == AuthStatus.loading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: () => _submit(ref),
                            child: Text(_isLogin ? 'Se connecter' : "S'inscrire"),
                          ),
                          if (state.errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              state.errorMessage!,
                              style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Bouton d'alternance Mode
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _formKey.currentState?.reset();
                      });
                    },
                    child: Text(
                      _isLogin
                          ? "Pas encore de compte ? S'inscrire"
                          : "Déjà un compte ? Se connecter",
                      style: const TextStyle(color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
