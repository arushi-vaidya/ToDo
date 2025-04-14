// lib/pages/smart_todo_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/time_slot.dart';

class SmartTodoListPage extends StatefulWidget {
  final List<Task> tasks;
  final List<Task> priorityTasks;
  final Function(Task) onTaskAdded;
  final Function(int, bool) onTaskCompleted;
  final Function(int) onTaskDeleted;
  
  const SmartTodoListPage({
    Key? key, 
    required this.tasks,
    required this.priorityTasks,
    required this.onTaskAdded,
    required this.onTaskCompleted,
    required this.onTaskDeleted,
  }) : super(key: key);

  @override
  State<SmartTodoListPage> createState() => _SmartTodoListPageState();
}

class _SmartTodoListPageState extends State<SmartTodoListPage> {
  final TextEditingController _textController = TextEditingController();
  List<TimeSlot> _availableTimeSlots = [];
  
  @override
  void initState() {
    super.initState();
    _generateAvailableTimeSlots();
  }
  
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
  
  void _generateAvailableTimeSlots() {
    // In a real app, this would come from user preferences or calendar integration
    final now = DateTime.now();
    
    // Example: Generate time slots for today
    _availableTimeSlots = [
      TimeSlot(
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 10, minute: 30),
        date: DateTime(now.year, now.month, now.day),
      ),
      TimeSlot(
        startTime: TimeOfDay(hour: 14, minute: 0),
        endTime: TimeOfDay(hour: 16, minute: 0),
        date: DateTime(now.year, now.month, now.day),
      ),
      TimeSlot(
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 11, minute: 0),
        date: DateTime(now.year, now.month, now.day + 1),
      ),
    ];
  }
  
  void _addTask(String title) async {
    // First, get basic task information
    final task = await _showTaskDetailsDialog(title);
    if (task != null) {
      // Then, suggest auto-scheduling if requested
      final shouldAutoSchedule = await _showAutoScheduleDialog();
      if (shouldAutoSchedule) {
        final slot = await _showTimeSlotSelectionDialog();
        if (slot != null) {
          // Apply the selected time slot to the task
          task.deadline = DateTime(
            slot.date.year,
            slot.date.month,
            slot.date.day,
            slot.startTime.hour,
            slot.startTime.minute,
          );
        }
      }
      
      // Add the task
      widget.onTaskAdded(task);
      _textController.clear();
    }
  }
  
  Future<Task?> _showTaskDetailsDialog(String title) async {
    int priority = 3;
    int estimatedMinutes = 30;
    List<String> selectedTags = [];
    final List<String> availableTags = ['Work', 'Personal', 'Urgent', 'Health', 'Study', 'Errands'];
    
    return showDialog<Task>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Task Details', style: TextStyle(color: Colors.cyan)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Task: $title', style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  const Text('Priority:', style: TextStyle(color: Colors.white70)),
                  Slider(
                    value: priority.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _getPriorityLabel(priority),
                    activeColor: _getPriorityColor(priority),
                    onChanged: (value) {
                      setState(() {
                        priority = value.round();
                      });
                    }
                  ),
                  const SizedBox(height: 16),
                  const Text('Estimated Time (minutes):', style: TextStyle(color: Colors.white70)),
                  Slider(
                    value: estimatedMinutes.toDouble(),
                    min: 5,
                    max: 240,
                    divisions: 47,
                    label: '$estimatedMinutes min',
                    activeColor: Colors.cyan,
                    onChanged: (value) {
                      setState(() {
                        estimatedMinutes = value.round();
                      });
                    }
                  ),
                  const SizedBox(height: 16),
                  const Text('Tags:', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        backgroundColor: Colors.grey[800],
                        selectedColor: Colors.cyan.withOpacity(0.3),
                        checkmarkColor: Colors.cyan,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedTags.add(tag);
                            } else {
                              selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(Task(
                    title: title,
                    priority: priority,
                    estimatedMinutes: estimatedMinutes,
                    tags: selectedTags,
                  ));
                },
                child: const Text('Save', style: TextStyle(color: Colors.cyan)),
              ),
            ],
          );
        }
      ),
    );
  }
  
  Future<bool> _showAutoScheduleDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Auto-Schedule?', style: TextStyle(color: Colors.cyan)),
        content: const Text(
          'Would you like to automatically schedule this task based on your available time slots?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: const Text('Yes', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    ) ?? false;
  }
  
  Future<TimeSlot?> _showTimeSlotSelectionDialog() async {
    return showDialog<TimeSlot>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Select Time Slot', style: TextStyle(color: Colors.cyan)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _availableTimeSlots.map((slot) {
              final date = DateFormat('EEE, MMM d').format(slot.date);
              final startTime = _formatTimeOfDay(slot.startTime);
              final endTime = _formatTimeOfDay(slot.endTime);
              
              return ListTile(
                title: Text('$date, $startTime - $endTime', style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  '${_getTimeDifferenceInMinutes(slot.startTime, slot.endTime)} minutes available',
                  style: const TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.of(context).pop(slot);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
  
  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 1: return 'Very Low';
      case 2: return 'Low';
      case 3: return 'Medium';
      case 4: return 'High';
      case 5: return 'Critical';
      default: return 'Medium';
    }
  }
  
  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1: return Colors.green;
      case 2: return Colors.teal;
      case 3: return Colors.cyan;
      case 4: return Colors.orange;
      case 5: return Colors.red;
      default: return Colors.cyan;
    }
  }
  
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  int _getTimeDifferenceInMinutes(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return endMinutes - startMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart To-Do List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Calendar View',
            onPressed: () {
              // Show calendar view (to be implemented)
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort Tasks',
            onPressed: _showSortDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Task Input Area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Enter your task...',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white10,
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) _addTask(value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.cyan,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () {
                      if (_textController.text.isNotEmpty) _addTask(_textController.text);
                    },
                    iconSize: 30,
                  ),
                ),
              ],
            ),
          ),
          
          // Priority Tasks
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Priority Tasks',
              style: TextStyle(color: Colors.redAccent, fontSize: 18),
            ),
          ),
          Expanded(
            flex: 1,
            child: widget.priorityTasks.isEmpty
              ? const Center(
                  child: Text(
                    'No priority tasks!',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: widget.priorityTasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(widget.priorityTasks[index], true, index);
                  },
                ),
          ),
          
          // Regular Tasks
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Tasks', style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
          Expanded(
            flex: 2,
            child: widget.tasks.isEmpty
              ? const Center(
                  child: Text(
                    'No tasks yet! Add some to get started.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: widget.tasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(widget.tasks[index], false, index);
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyan,
        child: const Icon(Icons.auto_awesome),
        onPressed: _showAutoScheduleAllDialog,
        tooltip: 'Auto-schedule all tasks',
      ),
    );
  }
  
  Widget _buildTaskCard(Task task, bool isPriority, int index) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (bool? value) {
            widget.onTaskCompleted(index, value ?? false);
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
                'Due: ${DateFormat('MMM d, h:mm a').format(task.deadline!)}',
                style: TextStyle(
                  fontSize: 12, 
                  color: _isTaskDueSoon(task.deadline!) ? Colors.redAccent : Colors.cyan,
                ),
              ),
          ],
        ),
        subtitle: task.tags.isNotEmpty ? Wrap(
          spacing: 4,
          children: task.tags.map((tag) => Chip(
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
                color: _getPriorityColor(task.priority).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${task.estimatedMinutes} min',
                style: TextStyle(
                  fontSize: 12,
                  color: _getPriorityColor(task.priority),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                widget.onTaskDeleted(index);
              },
            ),
          ],
        ),
        onTap: () {
          _showTaskDetailsEditDialog(task, index);
        },
      ),
    );
  }
  
  bool _isTaskDueSoon(DateTime deadline) {
    final now = DateTime.now();
    return deadline.difference(now).inHours < 24;
  }
  
  void _showTaskDetailsEditDialog(Task task, int index) async {
    // Show dialog to edit task details (similar to _showTaskDetailsDialog)
    // Implementation would be similar to _showTaskDetailsDialog but pre-filled
  }
  
  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Sort Tasks By', style: TextStyle(color: Colors.cyan)),
        children: [
          _buildSortOption('Priority (High to Low)', Icons.arrow_downward),
          _buildSortOption('Deadline (Soonest First)', Icons.calendar_today),
          _buildSortOption('Estimated Time (Quick First)', Icons.timer),
          _buildSortOption('Recently Added', Icons.history),
        ],
      ),
    );
  }
  
  Widget _buildSortOption(String title, IconData icon) {
    return SimpleDialogOption(
      onPressed: () {
        Navigator.pop(context);
        // Implement sorting logic here
      },
      child: Row(
        children: [
          Icon(icon, color: Colors.cyan),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
  
  void _showAutoScheduleAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Auto-Schedule All Tasks', style: TextStyle(color: Colors.cyan)),
        content: const Text(
          'Would you like to automatically schedule all unscheduled tasks based on your available time slots and priorities?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _autoScheduleAllTasks();
            },
            child: const Text('Auto-Schedule', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
  }
  
  void _autoScheduleAllTasks() {
    // Implement auto-scheduling logic here
    // This would assign time slots to tasks based on priority and available slots
  }
}