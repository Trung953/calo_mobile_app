import '../../data/models/diary_entry_model.dart';

abstract class DiaryState {}

class DiaryInitial extends DiaryState {}

class DiaryLoading extends DiaryState {}

class DiaryLoaded extends DiaryState {
  final CalorieSummaryModel summary;
  final List<DiaryEntryModel> meals;
  final String dateStr;

  DiaryLoaded({
    required this.summary,
    required this.meals,
    required this.dateStr,
  });
}

class DiaryError extends DiaryState {
  final String message;

  DiaryError({required this.message});
}