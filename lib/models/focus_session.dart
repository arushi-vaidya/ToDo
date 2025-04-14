// lib/models/focus_session.dart
import 'distraction_entry.dart';

class FocusSession {
  DateTime startTime;
  DateTime? endTime;
  int plannedDurationMinutes;
  int? actualDurationMinutes;
  String id;
  int initialMood;
  int? endMood;
  List<DistractionEntry> distractions;
  String? taskWorkedOn;

  FocusSession({
    required this.startTime,
    this.endTime,
    required this.plannedDurationMinutes,
    this.actualDurationMinutes,
    required this.id,
    required this.initialMood,
    this.endMood,
    this.distractions = const [],
    this.taskWorkedOn,
  });
}