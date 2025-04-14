// lib/models/time_slot.dart
import 'package:flutter/material.dart';

class TimeSlot {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final DateTime date;
  
  TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.date,
  });
}