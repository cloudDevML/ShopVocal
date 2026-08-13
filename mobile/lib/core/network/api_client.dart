import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/token_storage.dart';
import 'api_endpoints.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiClient(tokenStorage);
});

class ApiClient {
  final TokenStorage _tokenStorage;
  late final Dio _dio;

  ApiClient(this._tokenStorage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60), // 60s pour les appels de transcription vocale
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            debugPrint('[API] → ${options.method} ${options.path} | token: ${token.substring(0, token.length.clamp(0, 20))}...');
          } else {
            debugPrint('[API] → ${options.method} ${options.path} | ⚠️ AUCUN TOKEN');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('[API] ← ${response.statusCode} ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          final statusCode = e.response?.statusCode;
          debugPrint('[API] ✗ ${statusCode} ${e.requestOptions.path} | ${e.response?.data}');

          // 401 = token invalide ou expiré → suppression automatique
          if (statusCode == 401) {
            debugPrint('[API] 🔐 401 détecté → suppression du token stocké');
            await _tokenStorage.deleteToken();
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.post(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.put(path, data: data, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.delete(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    String errorMessage = "Une erreur est survenue lors de la communication avec le serveur.";
    if (e.response != null && e.response?.data is Map) {
      final detail = e.response?.data['detail'];
      errorMessage = detail is String ? detail : (e.response?.statusMessage ?? errorMessage);
    } else {
      errorMessage = e.message ?? errorMessage;
    }
    return Exception(errorMessage);
  }
}

