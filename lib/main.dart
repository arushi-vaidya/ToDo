import 'package:flutter/material.dart';
import 'dart:async';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helper',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const TodoListScreen(),
    );
  }
}

class Task {
  String title;
  bool isCompleted;
  DateTime? deadline;

  Task({required this.title, this.isCompleted = false, this.deadline});
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({Key? key}) : super(key: key);

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final List<Task> _tasks = [];
  final List<Task> _priorityTasks = [];
  final TextEditingController _textController = TextEditingController();
  int xp = 0;
  int streak = 0;
  int badges = 0;

  // Session durations
  Duration pomodoroDuration = const Duration(minutes: 25);
  Duration breakDuration = const Duration(minutes: 5);
  Duration remainingTime = Duration.zero;

  // Session states
  bool isPomodoroActive = false;
  bool isBreakActive = false;
  bool isPaused = false;
  Timer? timer;

  // XP rewards
  final int taskCompletionXP = 10;
  final int pomodoroCompletionXP = 25;
  final int focusMinuteXP = 1; // 1 XP per minute of focus

  // Reset all timer-related states
  void _resetTimerStates() {
    setState(() {
      timer?.cancel();
      timer = null;
      remainingTime = Duration.zero;
      isPomodoroActive = false;
      isBreakActive = false;
      isPaused = false;
    });
  }

  void _startTimerPopup(Duration duration, bool isPomodoro) {
    // Cancel any existing timer and reset states
    timer?.cancel();
    timer = null;

    // Initialize timer state
    setState(() {
      remainingTime = duration;
      isPaused = false;
      isPomodoroActive = isPomodoro;
      isBreakActive = !isPomodoro;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Start the timer
            timer = Timer.periodic(const Duration(seconds: 1), (t) {
              if (!isPaused) {
                if (remainingTime.inSeconds <= 1) {
                  t.cancel();
                  timer = null;

                  // Award XP for completed pomodoro session
                  if (isPomodoro) {
                    setState(() {
                      // Fixed XP reward for completing a pomodoro
                      xp += pomodoroCompletionXP;

                      // Additional XP based on focus duration (in minutes)
                      xp += (pomodoroDuration.inMinutes * focusMinuteXP);

                      // Update streak
                      streak++;
                      if (streak >= 5) {
                        badges++;
                        streak = 0;
                      }
                    });
                  }

                  // Close the dialog
                  Navigator.of(context).pop();

                  // Reset timer state
                  setState(() {
                    remainingTime = Duration.zero;
                    isPomodoroActive = false;
                    isBreakActive = false;
                  });

                  // Automatically start break after pomodoro, or vice versa
                  if (isPomodoro) {
                    // Offer to start a break
                    _showCompletionDialog('Pomodoro Complete!',
                        'You earned ${pomodoroCompletionXP + (pomodoroDuration.inMinutes * focusMinuteXP)} XP. Ready for a break?',
                            () => _startTimerPopup(breakDuration, false));
                  } else {
                    // Offer to start another pomodoro
                    _showCompletionDialog('Break Complete!',
                        'Ready for another pomodoro session?',
                            () => _startTimerPopup(pomodoroDuration, true));
                  }
                } else {
                  // Update remaining time
                  setDialogState(() {
                    remainingTime = remainingTime - const Duration(seconds: 1);
                  });
                }
              }
            });

            // Build the timer dialog
            return WillPopScope(
              onWillPop: () async {
                // Prevent accidental back button presses
                return false;
              },
              child: AlertDialog(
                backgroundColor: Colors.black87,
                title: Text(
                  isPomodoro ? 'Pomodoro Timer' : 'Break Timer',
                  style: TextStyle(
                    color: isPomodoro ? Colors.cyan : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDuration(remainingTime),
                      style: const TextStyle(fontSize: 48, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    if (isPomodoro)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'You\'ll earn ${pomodoroCompletionXP + (pomodoroDuration.inMinutes * focusMinuteXP)} XP when done!',
                          style: const TextStyle(color: Colors.cyan, fontSize: 14),
                        ),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setDialogState(() {
                        isPaused = !isPaused;
                      });
                    },
                    child: Text(isPaused ? 'Resume' : 'Pause',
                        style: TextStyle(color: isPomodoro ? Colors.cyan : Colors.green)),
                  ),
                  TextButton(
                    onPressed: () {
                      timer?.cancel();
                      timer = null;
                      Navigator.of(context).pop();
                      _resetTimerStates();
                    },
                    child: const Text('End', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      // Ensure timer is cancelled when dialog is closed
      timer?.cancel();
      timer = null;
    });
  }

  void _showCompletionDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: Text(title, style: const TextStyle(color: Colors.cyan)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              // Reset all timer states when skipping
              _resetTimerStates();
              Navigator.of(context).pop();
            },
            child: const Text('Skip', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // This will start a new timer and reset the current one
              onConfirm();
            },
            child: const Text('Start', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _addTask(String title) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null) {
      final TimeOfDay? selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(DateTime.now()),
      );

      if (selectedTime != null) {
        final DateTime selectedDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );

        setState(() {
          _tasks.add(Task(title: title, deadline: selectedDateTime));
        });
        _textController.clear();
      }
    }
  }

  void _editTaskDateTime(int index) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _tasks[index].deadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null) {
      final TimeOfDay? selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_tasks[index].deadline ?? DateTime.now()),
      );

      if (selectedTime != null) {
        final DateTime selectedDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );

        setState(() {
          _tasks[index].deadline = selectedDateTime;
        });
      }
    }
  }

  void _toggleTask(int index) {
    setState(() {
      _tasks[index].isCompleted = !_tasks[index].isCompleted;
      if (_tasks[index].isCompleted) {
        xp += taskCompletionXP;
        streak++;
      } else {
        xp = (xp >= 5) ? xp - 5 : 0; // Prevent negative XP
        streak = 0;
      }
      if (streak >= 5) {
        badges++;
        streak = 0;
      }
    });
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
  }

  void _moveToPriorityTasks() {
    final currentDateTime = DateTime.now();
    final expiredTasks = _tasks.where((task) =>
    task.deadline != null &&
        task.deadline!.isBefore(currentDateTime) &&
        !task.isCompleted
    ).toList();

    if (expiredTasks.isNotEmpty) {
      setState(() {
        for (var task in expiredTasks) {
          _priorityTasks.add(task);
          _tasks.remove(task);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _moveToPriorityTasks();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Helper'),
        actions: [
          IconButton(
              icon: const Icon(Icons.timer, color: Colors.cyan),
              tooltip: 'Start Pomodoro',
              onPressed: () => _startTimerPopup(pomodoroDuration, true)
          ),
          IconButton(
              icon: const Icon(Icons.brightness_2, color: Colors.green),
              tooltip: 'Start Break',
              onPressed: () => _startTimerPopup(breakDuration, false)
          ),
        ],
      ),
      body: Column(
        children: [
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Require Immediate Attention!!!',
              style: TextStyle(color: Colors.redAccent, fontSize: 18),
            ),
          ),
          Expanded(
            child: _priorityTasks.isEmpty
                ? const Center(
              child: Text(
                'No overdue tasks!',
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: _priorityTasks.length,
              itemBuilder: (context, index) {
                return Card(
                  color: Colors.grey[900],
                  child: ListTile(
                    leading: Checkbox(
                      value: _priorityTasks[index].isCompleted,
                      onChanged: (bool? value) {
                        setState(() {
                          _priorityTasks[index].isCompleted = value!;
                          if (value) {
                            xp += taskCompletionXP;
                            streak++;
                            if (streak >= 5) {
                              badges++;
                              streak = 0;
                            }
                          }
                        });
                      },
                    ),
                    title: Text(
                      _priorityTasks[index].title,
                      style: TextStyle(
                        decoration: _priorityTasks[index].isCompleted ? TextDecoration.lineThrough : null,
                        color: _priorityTasks[index].isCompleted ? Colors.grey : Colors.white,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _priorityTasks.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Tasks', style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
          Expanded(
            child: _tasks.isEmpty
                ? const Center(
              child: Text(
                'No tasks yet! Add some to get started.',
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                return Card(
                  color: Colors.grey[900],
                  child: ListTile(
                    leading: Checkbox(
                      value: _tasks[index].isCompleted,
                      onChanged: (bool? value) {
                        _toggleTask(index);
                      },
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tasks[index].title,
                          style: TextStyle(
                            decoration: _tasks[index].isCompleted ? TextDecoration.lineThrough : null,
                            color: _tasks[index].isCompleted ? Colors.grey : Colors.white,
                          ),
                        ),
                        if (_tasks[index].deadline != null)
                          Text(
                            'Due: ${_tasks[index].deadline!.day}/${_tasks[index].deadline!.month}/${_tasks[index].deadline!.year} ${_tasks[index].deadline!.hour}:${_tasks[index].deadline!.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: () => _editTaskDateTime(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: () => _deleteTask(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8.0),
            ),
            margin: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statsItem('XP', xp, Icons.star, Colors.amber),
                _statsItem('Streak', streak, Icons.local_fire_department, Colors.orange),
                _statsItem('Badges', badges, Icons.workspace_premium, Colors.cyan),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsItem(String label, int value, IconData icon, Color color) {
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

  @override
  void dispose() {
    _textController.dispose();
    timer?.cancel();
    super.dispose();
  }
}