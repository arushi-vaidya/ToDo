import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;


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

class MoodEntry {
  int rating; // 1-5 representing sad to happy
  DateTime timestamp;
  String sessionType; // "Focus" or "Break"

  MoodEntry({required this.rating, required this.timestamp, required this.sessionType});
}

class ProductivityEntry {
  DateTime date;
  int tasksCompleted;
  int focusMinutes;

  ProductivityEntry({required this.date, required this.tasksCompleted, required this.focusMinutes});
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({Key? key}) : super(key: key);

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> with SingleTickerProviderStateMixin {
  final List<Task> _tasks = [];
  final List<Task> _priorityTasks = [];
  final TextEditingController _textController = TextEditingController();
  int xp = 0;
  int streak = 0;
  int badges = 0;

  // Session durations
  Duration pomodoroDuration = const Duration(minutes: 1);
  Duration breakDuration = const Duration(minutes: 1);
  Duration remainingTime = Duration.zero;

  // Session states
  bool isPomodoroActive = false;
  bool isBreakActive = false;
  bool isPaused = false;
  Timer? timer;

  // XP rewards - constants
  final int taskCompletionXP = 10;
  final int pomodoroCompletionXP = 25;
  final int focusMinuteXP = 1; // 1 XP per minute of focus

  // Mood tracking
  final List<MoodEntry> _moodEntries = [];

  // Productivity tracking
  final List<ProductivityEntry> _productivityEntries = [];
  int focusSessionsToday = 0;
  int focusMinutesToday = 0;
  int tasksCompletedToday = 0;

  // Tab controller
  late TabController _tabController;

  // Create notification plugin instance
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeProductivityData();

    // Initialize notifications
    initNotifications().catchError((error) {
      print('Failed to initialize notifications: $error');
    });
  }

  // Initialize notifications
  Future<void> initNotifications() async {
    // Initialize timezone
    tz.initializeTimeZones();

    // Initialize Android settings
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize iOS settings
    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialize settings for all platforms
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Notification tapped: ${response.payload}');
      },
    );
  }

  // Schedule a notification for a task
  Future<void> scheduleTaskReminder(int taskId, String taskTitle, DateTime deadline) async {
    // Calculate time before deadline for reminder (30 minutes before)
    final reminderTime = deadline.subtract(const Duration(minutes: 30));

    // Skip if reminder time is in the past
    if (reminderTime.isBefore(DateTime.now())) {
      return;
    }

    // Android notification details
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'task_reminders_channel',
      'Task Reminders',
      channelDescription: 'Notifications for upcoming tasks',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
    );

    // iOS notification details
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    // Notification details for all platforms
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Schedule the notification
    await flutterLocalNotificationsPlugin.zonedSchedule(
      taskId,
      'Task Reminder',
      'Your task "$taskTitle" is due in 30 minutes',
      tz.TZDateTime.from(reminderTime, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // optional, if you're setting recurring
      payload: taskId.toString(),
    );
  }

  // Cancel a specific notification
  Future<void> cancelTaskReminder(int taskId) async {
    await flutterLocalNotificationsPlugin.cancel(taskId);
  }

  // Cancel all notifications
  Future<void> cancelAllReminders() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  void _initializeProductivityData() {
    // Initialize with some dummy data for demonstration
    final now = DateTime.now();
    final random = Random();

    // Generate past 7 days of data
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      _productivityEntries.add(
          ProductivityEntry(
            date: date,
            tasksCompleted: random.nextInt(8),
            focusMinutes: random.nextInt(120),
          )
      );
    }

    // Initialize today's entry
    _updateOrCreateTodayProductivityEntry();
  }

  void _updateOrCreateTodayProductivityEntry() {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final existingEntryIndex = _productivityEntries.indexWhere(
            (entry) => entry.date.year == today.year &&
            entry.date.month == today.month &&
            entry.date.day == today.day
    );

    if (existingEntryIndex >= 0) {
      _productivityEntries[existingEntryIndex].tasksCompleted = tasksCompletedToday;
      _productivityEntries[existingEntryIndex].focusMinutes = focusMinutesToday;
    } else {
      _productivityEntries.add(
          ProductivityEntry(
            date: today,
            tasksCompleted: tasksCompletedToday,
            focusMinutes: focusMinutesToday,
          )
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

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

  // Calculate XP for a completed Pomodoro session
  int _calculatePomodoroXp() {
    return pomodoroCompletionXP + (pomodoroDuration.inMinutes * focusMinuteXP);
  }

  void _startTimerPopup(Duration duration, bool isPomodoro) {
    // Cancel any existing timer and reset states
    timer?.cancel();

    // Set initial timer state
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
            void startTimer() {
              timer = Timer.periodic(const Duration(seconds: 1), (t) {
                if (!isPaused) {
                  if (remainingTime.inSeconds <= 1) {
                    t.cancel();
                    timer = null;

                    // Award XP for completed pomodoro session
                    if (isPomodoro) {
                      setState(() {
                        int earnedXp = _calculatePomodoroXp();
                        xp += earnedXp;

                        // Update productivity metrics
                        focusSessionsToday++;
                        focusMinutesToday += pomodoroDuration.inMinutes;
                        _updateOrCreateTodayProductivityEntry();

                        // Update streak
                        streak++;
                        if (streak >= 5) {
                          badges++;
                          streak = 0;
                        }
                      });
                    }

                    // Close the dialog
                    Navigator.of(context).pop(true); // Use a result to indicate completion
                  } else {
                    // Update remaining time
                    setDialogState(() {
                      remainingTime = remainingTime - const Duration(seconds: 1);
                    });
                  }
                }
              });
            }

            // Start the timer when dialog is shown
            if (timer == null) {
              startTimer();
            }

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
                          'You\'ll earn ${_calculatePomodoroXp()} XP when done!',
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
                      Navigator.of(context).pop(false); // Use a result to indicate cancellation
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
    ).then((completed) {
      // Ensure timer is cancelled when dialog is closed
      timer?.cancel();
      timer = null;

      // Only show completion dialog if the timer completed naturally (not cancelled)
      if (completed == true) {
        // Show mood tracking dialog before completion dialog
        _showMoodDialog(isPomodoro ? 'Focus' : 'Break').then((_) {
          // After mood is recorded, show completion dialog
          _showCompletionDialog(
            isPomodoro ? 'Pomodoro Complete!' : 'Break Complete!',
            isPomodoro ? 'You earned ${_calculatePomodoroXp()} XP. Ready for a break?'
                : 'Ready for another pomodoro session?',
                () => _startTimerPopup(isPomodoro ? breakDuration : pomodoroDuration, !isPomodoro),
          );
        });

        // Reset timer states for the main screen
        setState(() {
          remainingTime = Duration.zero;
          isPomodoroActive = false;
          isBreakActive = false;
        });
      }
    });
  }

  Future<void> _showMoodDialog(String sessionType) {
    int selectedMood = 3; // Default to neutral mood

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.black87,
            title: Text('How do you feel after this $sessionType session?',
                style: const TextStyle(color: Colors.cyan)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (int i = 1; i <= 5; i++)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedMood = i;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selectedMood == i ? Colors.cyan.withOpacity(0.3) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getMoodEmoji(i),
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(_getMoodDescription(selectedMood),
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Add mood entry to the list
                  this.setState(() {
                    _moodEntries.add(MoodEntry(
                      rating: selectedMood,
                      timestamp: DateTime.now(),
                      sessionType: sessionType,
                    ));
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Submit', style: TextStyle(color: Colors.cyan)),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getMoodEmoji(int rating) {
    switch (rating) {
      case 1: return '😢';
      case 2: return '😕';
      case 3: return '😐';
      case 4: return '🙂';
      case 5: return '😄';
      default: return '😐';
    }
  }

  String _getMoodDescription(int rating) {
    switch (rating) {
      case 1: return 'Very Unhappy';
      case 2: return 'Unhappy';
      case 3: return 'Neutral';
      case 4: return 'Happy';
      case 5: return 'Very Happy';
      default: return 'Neutral';
    }
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
              // This will start a new timer
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

        // Schedule a reminder
        int taskId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
        try {
          await scheduleTaskReminder(taskId, title, selectedDateTime);
        } catch (e) {
          print('Failed to schedule notification: $e');
        }

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
        // Cancel notification since task is completed
        int taskId = index; // Use appropriate ID here
        cancelTaskReminder(taskId);

        // Award XP and update stats
        xp += taskCompletionXP;
        streak++;
        tasksCompletedToday++;
        _updateOrCreateTodayProductivityEntry();
      } else {
        xp = (xp >= 5) ? xp - 5 : 0; // Prevent negative XP
        streak = 0;
        if (tasksCompletedToday > 0) {
          tasksCompletedToday--;
          _updateOrCreateTodayProductivityEntry();
        }
      }

      if (streak >= 5) {
        badges++;
        streak = 0;
      }
    });
  }

  void _deleteTask(int index) {
    setState(() {
      int taskId = index; // Use appropriate ID here
      cancelTaskReminder(taskId);
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

  // Method to build heatmap for both productivity and mood
  Widget _buildHeatmaps() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Productivity',
              style: TextStyle(fontSize: 20, color: Colors.cyan, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildProductivityHeatmap(),
            const SizedBox(height: 24),
            const Text(
              'Weekly Mood',
              style: TextStyle(fontSize: 20, color: Colors.cyan, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildMoodHeatmap(),
            const SizedBox(height: 24),
            _buildMoodSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductivityHeatmap() {
    // Get last 7 days for display
    final List<ProductivityEntry> weekData = _productivityEntries.length > 7
        ? _productivityEntries.sublist(_productivityEntries.length - 7)
        : _productivityEntries;

    return Column(
      children: [
        // Tasks completed heatmap
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tasks Completed', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Row(
              children: weekData.map((entry) {
                final intensity = entry.tasksCompleted > 10 ? 1.0 : entry.tasksCompleted / 10;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Column(
                      children: [
                        Text(DateFormat('E').format(entry.date),
                            style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        const SizedBox(height: 4),
                        Container(
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.cyan.withOpacity(intensity),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '${entry.tasksCompleted}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Focus minutes heatmap
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Focus Minutes', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Row(
              children: weekData.map((entry) {
                final intensity = entry.focusMinutes > 120 ? 1.0 : entry.focusMinutes / 120;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Column(
                      children: [
                        Text(DateFormat('E').format(entry.date),
                            style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        const SizedBox(height: 4),
                        Container(
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(intensity),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '${entry.focusMinutes}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoodHeatmap() {
    // Group mood data by day
    Map<String, List<MoodEntry>> groupedMoods = {};

    for (var entry in _moodEntries) {
      final dateStr = DateFormat('yyyy-MM-dd').format(entry.timestamp);
      if (!groupedMoods.containsKey(dateStr)) {
        groupedMoods[dateStr] = [];
      }
      groupedMoods[dateStr]!.add(entry);
    }

    // Create weekly data (last 7 days)
    final now = DateTime.now();
    List<MapEntry<String, double>> weeklyMoodData = [];

    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      double avgMood = 3.0; // Default neutral

      if (groupedMoods.containsKey(dateStr) && groupedMoods[dateStr]!.isNotEmpty) {
        double sum = groupedMoods[dateStr]!.fold(0, (prev, curr) => prev + curr.rating);
        avgMood = sum / groupedMoods[dateStr]!.length;
      }

      weeklyMoodData.add(MapEntry(dateStr, avgMood));
    }

    return Row(
      children: weeklyMoodData.map((entry) {
        final date = DateFormat('yyyy-MM-dd').parse(entry.key);
        final averageMood = entry.value;

        // Map mood to colors
        Color moodColor;
        if (averageMood < 2) {
          moodColor = Colors.red[400]!;
        } else if (averageMood < 3) {
          moodColor = Colors.orange[400]!;
        } else if (averageMood < 4) {
          moodColor = Colors.yellow[400]!;
        } else if (averageMood < 4.5) {
          moodColor = Colors.lightGreen[400]!;
        } else {
          moodColor = Colors.green[400]!;
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: Column(
              children: [
                Text(DateFormat('E').format(date),
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 4),
                Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: moodColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      _getMoodEmoji(averageMood.round()),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMoodSummary() {
    // Calculate recent mood stats
    if (_moodEntries.isEmpty) {
      return const Card(
        color: Colors.black45,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No mood data available yet. Complete focus and break sessions to start tracking your mood!',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // Calculate averages for focus and break sessions
    double avgFocusMood = 0;
    double avgBreakMood = 0;
    int focusCount = 0;
    int breakCount = 0;

    for (var entry in _moodEntries) {
      if (entry.sessionType == 'Focus') {
        avgFocusMood += entry.rating;
        focusCount++;
      } else {
        avgBreakMood += entry.rating;
        breakCount++;
      }
    }

    avgFocusMood = focusCount > 0 ? avgFocusMood / focusCount : 0;
    avgBreakMood = breakCount > 0 ? avgBreakMood / breakCount : 0;

    return Card(
      color: Colors.black45,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mood Insights',
              style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMoodStat(
                      'Average Focus Mood',
                      avgFocusMood,
                      Colors.cyan
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMoodStat(
                      'Average Break Mood',
                      avgBreakMood,
                      Colors.green
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Total Entries: ${_moodEntries.length} (${focusCount} focus, ${breakCount} break)',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildMoodStat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              _getMoodEmoji(value.round()),
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 8),
            Text(
              value > 0 ? value.toStringAsFixed(1) : 'N/A',
              style: TextStyle(
                fontSize: 18,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.task), text: 'Tasks'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
          indicatorColor: Colors.cyan,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tasks Tab
          Column(
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
                                tasksCompletedToday++;
                                _updateOrCreateTodayProductivityEntry();
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

          // Analytics Tab
          _buildHeatmaps(),
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
}