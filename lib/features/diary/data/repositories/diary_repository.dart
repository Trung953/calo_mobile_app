import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../models/diary_entry_model.dart';
import '../models/food_model.dart';

class DiaryRepository {
  final ApiClient apiClient;

  DiaryRepository({required this.apiClient});

  Future<Map<String, dynamic>> getDailySummary(String dateStr) async {
    final res = await apiClient.get('${ApiEndpoints.diary}?date=$dateStr');
    return res['data'] ?? res;
  }

  Future<Map<String, dynamic>> getDailyDiary(String dateStr) async {
    return getDailySummary(dateStr);
  }

  Future<List<FoodModel>> searchFoods(String query) async {
    final res = await apiClient.get('${ApiEndpoints.foods}?search=$query');
    final List list = res['data'] ?? [];
    return list.map((e) => FoodModel.fromJson(e)).toList();
  }

  Future<DiaryEntryModel> addDiaryEntry(DiaryEntryModel entry) async {
    final res = await apiClient.post(ApiEndpoints.diary, {
      'foodId': entry.foodId,
      'mealType': entry.mealType,
      'quantity': entry.quantity,
      'date': entry.date,
    });
    return DiaryEntryModel.fromJson(res['data'] ?? res);
  }

  Future<DiaryEntryModel> updateDiaryEntry(String id, Map<String, dynamic> updates) async {
    final res = await apiClient.put('${ApiEndpoints.diary}/$id', updates);
    return DiaryEntryModel.fromJson(res['data'] ?? res);
  }

  Future<void> deleteDiaryEntry(String id) async {
    await apiClient.delete('${ApiEndpoints.diary}/$id');
  }

  Future<void> deleteMealLog(String logId) async {
    await deleteDiaryEntry(logId);
  }

  Future<FoodModel> createCustomFood({
    String? name,
    double? servingSizeWeight,
    String? servingSizeUnit,
    int? calories,
    double? carbsG,
    double? proteinG,
    double? fatG,
    Map<String, dynamic>? data,
  }) async {
    final payload = data ?? {
      'name': name ?? '',
      'caloriesPer100g': calories ?? 0,
      'proteinPer100g': proteinG ?? 0.0,
      'carbsPer100g': carbsG ?? 0.0,
      'fatPer100g': fatG ?? 0.0,
      'defaultServing': servingSizeWeight ?? 100.0,
      'isCustom': true,
    };

    final res = await apiClient.post(
      '${ApiEndpoints.foods}/custom',
      payload,
    );
    return FoodModel.fromJson(res['data'] ?? res);
  }
}