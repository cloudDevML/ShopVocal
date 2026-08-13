import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(apiClient);
});

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;

  AuthState({required this.status, this.errorMessage});

  AuthState copyWith({AuthStatus? status, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final TokenStorage _tokenStorage;

  AuthNotifier(this._authRepository, this._tokenStorage)
      : super(AuthState(status: AuthStatus.initial)) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    debugPrint('[AUTH] checkAuth() démarré');
    try {
      final token = await _tokenStorage.getToken();
      debugPrint('[AUTH] Token trouvé en storage: ${token != null ? "OUI (${token.substring(0, token.length.clamp(0, 30))}...)" : "NON"}');
      if (token != null && token.isNotEmpty) {
        state = AuthState(status: AuthStatus.authenticated);
        debugPrint('[AUTH] → Status: AUTHENTICATED');
      } else {
        state = AuthState(status: AuthStatus.unauthenticated);
        debugPrint('[AUTH] → Status: UNAUTHENTICATED (pas de token)');
      }
    } catch (e) {
      debugPrint('[AUTH] checkAuth() erreur: $e');
      state = AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String phoneNumber, String password) async {
    debugPrint('[AUTH] login() avec phone=$phoneNumber');
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final token = await _authRepository.login(phoneNumber, password);
      await _tokenStorage.saveToken(token);
      debugPrint('[AUTH] login() réussi → token sauvegardé');
      state = AuthState(status: AuthStatus.authenticated);
    } catch (e) {
      debugPrint('[AUTH] login() ERREUR: $e');
      state = AuthState(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> register(String phoneNumber, String password, String? fullName) async {
    debugPrint('[AUTH] register() avec phone=$phoneNumber');
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final token = await _authRepository.register(phoneNumber, password, fullName);
      await _tokenStorage.saveToken(token);
      debugPrint('[AUTH] register() réussi → token sauvegardé');
      state = AuthState(status: AuthStatus.authenticated);
    } catch (e) {
      debugPrint('[AUTH] register() ERREUR: $e');
      state = AuthState(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> logout() async {
    debugPrint('[AUTH] logout() → suppression du token');
    await _tokenStorage.deleteToken();
    state = AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  return AuthNotifier(authRepository, tokenStorage);
});

