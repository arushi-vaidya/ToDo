// lib/models/task.dart
import 'package:flutter/material.dart';

class Task {
  final String id; // ✅ Unique identifier for each task
  String title;
  bool isCompleted;
  DateTime? deadline;
  int priority; // 1-5, 5 being highest
  int estimatedMinutes; // How long the task might take
  TimeOfDay? preferredStartTime; // When user prefers to start this task
  List<String> tags; // For categorizing tasks
  String? notes; // Nullable string for notes

  Task({
    required this.id, // ✅ Now required in constructor
    required this.title, 
    this.isCompleted = false, 
    this.deadline,
    this.priority = 3,
    this.estimatedMinutes = 30,
    this.preferredStartTime,
    this.tags = const [],
    this.notes,
  });

  // ✅ Optional: add copyWith method for updating tasks safely
  Task copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? deadline,
    int? priority,
    int? estimatedMinutes,
    TimeOfDay? preferredStartTime,
    List<String>? tags,
    String? notes,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      preferredStartTime: preferredStartTime ?? this.preferredStartTime,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
    );
  }
}
