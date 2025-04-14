// lib/models/task.dart
import 'package:flutter/material.dart';

class Task {
  String title;
  bool isCompleted;
  DateTime? deadline;
  int priority; // 1-5, 5 being highest
  int estimatedMinutes; // How long the task might take
  TimeOfDay? preferredStartTime; // When user prefers to start this task
  List<String> tags; // For categorizing tasks

  Task({
    required this.title, 
    this.isCompleted = false, 
    this.deadline,
    this.priority = 3,
    this.estimatedMinutes = 30,
    this.preferredStartTime,
    this.tags = const [],
  });
}