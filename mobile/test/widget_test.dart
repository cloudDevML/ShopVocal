import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/main.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/storage/token_storage.dart';

// Mock de TokenStorage pour éviter d'appeler les canaux natifs de flutter_secure_storage en test
class FakeTokenStorage extends TokenStorage {
  String? _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }

  @override
  Future<String?> getToken() async {
    return _token;
  }

  @override
  Future<void> deleteToken() async {
    _token = null;
  }

  @override
  Future<bool> hasToken() async {
    return _token != null && _token!.isNotEmpty;
  }
}

void main() {
  testWidgets('AuthScreen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame, with TokenStorage simulé en mémoire.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
        ],
        child: const MyApp(),
      ),
    );

    // Attendre la résolution de l'authentification initiale (checkAuth)
    await tester.pump(const Duration(milliseconds: 100));

    // Vérifier que l'écran d'authentification s'affiche bien.
    expect(find.text('Connexion Commerçant'), findsOneWidget);
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
