// lib/models/mood_entry.dart

class MoodEntry {
  int rating; // 1-5 representing sad to happy
  DateTime timestamp;
  String sessionType; // "Focus" or "Break"
  String? note; // Optional note about mood

  MoodEntry({
    required this.rating, 
    required this.timestamp, 
    required this.sessionType,
    this.note,
  });
}