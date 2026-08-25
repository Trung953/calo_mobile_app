import 'package:flutter/foundation.dart';

class ApiEndpoints {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api/v1';
    }
    return 'https://healthlog-api.onrender.com/api/v1';
  }

  static String get register => '$baseUrl/auth/register';
  static String get login => '$baseUrl/auth/login';
  static String get google => '$baseUrl/auth/google';
  static String get foods => '$baseUrl/foods';
  static String get customFoods => '$baseUrl/foods/custom'; // <-- Thêm endpoint này
  static String get diary => '$baseUrl/diary';
  static String get profile => '$baseUrl/profile';
  static String get weights => '$baseUrl/weights';
  static String get stats => '$baseUrl/stats';
  static String get water => '$baseUrl/water';
  static String get exercises => '$baseUrl/exercises';
  static String get favorites => '$baseUrl/favorites';
}