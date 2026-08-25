import '../../data/models/diary_entry_model.dart';

abstract class DiaryEvent {}

class LoadDailyDiary extends DiaryEvent {
  final String dateStr;
  LoadDailyDiary({required this.dateStr});
}

class AddDiaryEntryEvent extends DiaryEvent {
  final DiaryEntryModel entry;
  AddDiaryEntryEvent({required this.entry});
}

class UpdateDiaryEntryEvent extends DiaryEvent {
  final String id;
  final String currentDate;
  final Map<String, dynamic> updates;

  UpdateDiaryEntryEvent({
    required this.id,
    required this.currentDate,
    required this.updates,
  });
}

class DeleteDiaryEntryEvent extends DiaryEvent {
  final String id;
  final String currentDate;

  DeleteDiaryEntryEvent({
    required this.id,
    required this.currentDate,
  });
}