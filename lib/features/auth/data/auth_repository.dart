import 'package:mobile_app/core/constants/api_endpoints.dart';
import 'package:mobile_app/core/network/api_client.dart';

class AuthRepository {
  final ApiClient apiClient;

  AuthRepository({required this.apiClient});

  Future<void> login(String email, String password) async {
    final response = await apiClient.post(ApiEndpoints.login, {
      'email': email,
      'password': password,
    });
    final token = response['token'];
    if (token != null) {
      await apiClient.saveToken(token);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String gender,
    required String birthDate,
    required double heightCm,
    required double currentWeightKg,
    required String activityLevel,
    required String goal,
  }) async {
    final response = await apiClient.post(ApiEndpoints.register, {
      'email': email,
      'password': password,
      'fullName': fullName,
      'gender': gender,
      'birthDate': birthDate,
      'heightCm': heightCm,
      'currentWeightKg': currentWeightKg,
      'activityLevel': activityLevel,
      'goal': goal,
    });
    final token = response['token'];
    if (token != null) {
      await apiClient.saveToken(token);
    }
  }
}