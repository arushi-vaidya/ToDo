// lib/widgets/common_widgets.dart
import 'package:flutter/material.dart';

// Stats item widget used in the bottom bar
Widget statsItem(String label, int value, IconData icon, Color color) {
  return Row(
    children: [
      Icon(icon, color: color),
      const SizedBox(width: 4),
      Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    ],
  );
}

// Task card for todo list
Widget buildTaskCard(
  dynamic task, 
  bool isPriority, 
  int index, 
  Function(int, bool) onTaskCompleted,
  Function(int) onTaskDeleted,
  Function(dynamic, int) onTaskTap,
  Color Function(int) getPriorityColor,
  bool Function(DateTime) isTaskDueSoon,
) {
  return Card(
    color: Colors.grey[900],
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: ListTile(
      leading: Checkbox(
        value: task.isCompleted,
        onChanged: (bool? value) {
          onTaskCompleted(index, value ?? false);
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: TextStyle(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted ? Colors.grey : Colors.white,
              fontWeight: task.priority >= 4 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (task.deadline != null)
            Text(
              'Due: ${_formatDate(task.deadline!)}',
              style: TextStyle(
                fontSize: 12, 
                color: isTaskDueSoon(task.deadline!) ? Colors.redAccent : Colors.cyan,
              ),
            ),
        ],
      ),
      subtitle: task.tags.isNotEmpty ? Wrap(
        spacing: 4,
        children: task.tags.map<Widget>((tag) => Chip(
          label: Text(tag, style: const TextStyle(fontSize: 10)),
          backgroundColor: Colors.black,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        )).toList(),
      ) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: getPriorityColor(task.priority).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${task.estimatedMinutes} min',
              style: TextStyle(
                fontSize: 12,
                color: getPriorityColor(task.priority),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              onTaskDeleted(index);
            },
          ),
        ],
      ),
      onTap: () {
        onTaskTap(task, index);
      },
    ),
  );
}

// Format date helper
String _formatDate(DateTime date) {
  // You might want to use the intl package for better formatting
  return '${date.month}/${date.day}/${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}

// Build distraction counters for focus mode
Widget buildDistractionsCounter(String label, int count, IconData icon) {
  return Column(
    children: [
      Icon(
        icon,
        color: count > 0 ? Colors.orange : Colors.grey,
        size: 28,
      ),
      const SizedBox(height: 8),
      Text(
        '$count',
        style: TextStyle(
          color: count > 0 ? Colors.orange : Colors.grey,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: count > 0 ? Colors.orange : Colors.grey,
        ),
      ),
    ],
  );
}

// Format time for focus timer
String formatTime(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}