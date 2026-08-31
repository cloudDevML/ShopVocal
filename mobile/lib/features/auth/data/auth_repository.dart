import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'user_profile.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  Future<String> login(String phoneNumber, String password) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      data: {
        'phone_number': phoneNumber,
        'password': password,
      },
    );
    return response.data['access_token'];
  }

  Future<String> register(String phoneNumber, String password, String? fullName) async {
    final response = await _apiClient.post(
      ApiEndpoints.register,
      data: {
        'phone_number': phoneNumber,
        'password': password,
        'full_name': fullName,
      },
    );
    return response.data['access_token'];
  }

  Future<UserProfile> getProfile() async {
    final response = await _apiClient.get(ApiEndpoints.me);
    return UserProfile.fromJson(response.data);
  }

  Future<UserProfile> updateProfile({String? fullName, String? password}) async {
    final Map<String, dynamic> data = {};
    if (fullName != null) data['full_name'] = fullName;
    if (password != null && password.isNotEmpty) data['password'] = password;
    final response = await _apiClient.put(
      ApiEndpoints.me,
      data: data,
    );
    return UserProfile.fromJson(response.data);
  }
}
