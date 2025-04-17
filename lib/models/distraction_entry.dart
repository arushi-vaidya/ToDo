// lib/models/distraction_entry.dart

class DistractionEntry {
  DateTime timestamp;
  String type; // "Phone", "Movement", "App Switch", etc.
  int durationSeconds; // How long the distraction lasted
  String? sessionId; // To link with a specific focus session

  DistractionEntry({
    required this.timestamp,
    required this.type,
    required this.durationSeconds,
    this.sessionId,
  });
}