import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../models/diary_entry_model.dart';

abstract class DiaryRemoteDataSource {
  Future<Map<String, dynamic>> getDiaryByDate(String dateStr);
  Future<DiaryEntryModel> createDiaryEntry(DiaryEntryModel entry);
  Future<DiaryEntryModel> updateDiaryEntry(String id, Map<String, dynamic> updates);
  Future<void> deleteDiaryEntry(String id);
}

class DiaryRemoteDataSourceImpl implements DiaryRemoteDataSource {
  final ApiClient apiClient;

  DiaryRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<Map<String, dynamic>> getDiaryByDate(String dateStr) async {
    final response = await apiClient.get('${ApiEndpoints.diary}?date=$dateStr');
    final data = response['data'] ?? {};
    final List list = data['meals'] ?? [];

    return {
      'summary': data['summary'] ?? {},
      'meals': list.map((e) => DiaryEntryModel.fromJson(e)).toList(),
    };
  }

  @override
  Future<DiaryEntryModel> createDiaryEntry(DiaryEntryModel entry) async {
    final response = await apiClient.post(ApiEndpoints.diary, entry.toJson());
    return DiaryEntryModel.fromJson(response['data']);
  }

  @override
  Future<DiaryEntryModel> updateDiaryEntry(String id, Map<String, dynamic> updates) async {
    final response = await apiClient.put('${ApiEndpoints.diary}/$id', updates);
    return DiaryEntryModel.fromJson(response['data']);
  }

  @override
  Future<void> deleteDiaryEntry(String id) async {
    await apiClient.delete('${ApiEndpoints.diary}/$id');
  }
}