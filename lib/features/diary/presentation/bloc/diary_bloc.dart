import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/diary_entry_model.dart';
import '../../data/repositories/diary_repository.dart';
import 'diary_event.dart';
import 'diary_state.dart';

class DiaryBloc extends Bloc<DiaryEvent, DiaryState> {
  final DiaryRepository repository;

  DiaryBloc({required this.repository}) : super(DiaryInitial()) {
    on<LoadDailyDiary>(_onLoadDailyDiary);
    on<AddDiaryEntryEvent>(_onAddDiaryEntry);
    on<UpdateDiaryEntryEvent>(_onUpdateDiaryEntry);
    on<DeleteDiaryEntryEvent>(_onDeleteDiaryEntry);
  }

  Future<void> _onLoadDailyDiary(
    LoadDailyDiary event,
    Emitter<DiaryState> emit,
  ) async {
    emit(DiaryLoading());
    try {
      final res = await repository.getDailySummary(event.dateStr);

      final Map<String, dynamic> summaryMap =
          (res['summary'] is Map<String, dynamic>)
              ? res['summary'] as Map<String, dynamic>
              : (res['data'] is Map && res['data']['summary'] is Map)
                  ? Map<String, dynamic>.from(res['data']['summary'])
                  : <String, dynamic>{};

      final dynamic rawMeals = res['meals'] ?? (res['data'] is Map ? res['data']['meals'] : null) ?? [];

      final List<DiaryEntryModel> meals = (rawMeals is List)
          ? rawMeals
              .map((e) => e is DiaryEntryModel
                  ? e
                  : DiaryEntryModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : <DiaryEntryModel>[];

      final summary = CalorieSummaryModel.fromJson(summaryMap);

      emit(DiaryLoaded(
        summary: summary,
        meals: meals,
        dateStr: event.dateStr,
      ));
    } catch (e) {
      emit(DiaryError(message: e.toString()));
    }
  }

  Future<void> _onAddDiaryEntry(
    AddDiaryEntryEvent event,
    Emitter<DiaryState> emit,
  ) async {
    try {
      await repository.addDiaryEntry(event.entry);
      add(LoadDailyDiary(dateStr: event.entry.date));
    } catch (e) {
      emit(DiaryError(message: e.toString()));
    }
  }

  Future<void> _onUpdateDiaryEntry(
    UpdateDiaryEntryEvent event,
    Emitter<DiaryState> emit,
  ) async {
    try {
      await repository.updateDiaryEntry(event.id, event.updates);
      add(LoadDailyDiary(dateStr: event.currentDate));
    } catch (e) {
      emit(DiaryError(message: e.toString()));
    }
  }

  Future<void> _onDeleteDiaryEntry(
    DeleteDiaryEntryEvent event,
    Emitter<DiaryState> emit,
  ) async {
    try {
      await repository.deleteDiaryEntry(event.id);
      add(LoadDailyDiary(dateStr: event.currentDate));
    } catch (e) {
      emit(DiaryError(message: e.toString()));
    }
  }
}