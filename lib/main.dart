import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart'; // Added for accelerometer events

import 'pages/smart_todo_page.dart';
import 'pages/focus_mode_page.dart';
import 'pages/insights_page.dart';
import 'models/task.dart';
import 'models/mood_entry.dart';
import 'models/distraction_entry.dart';
import 'models/focus_session.dart';
import 'models/productivity_entry.dart';
import 'models/time_slot.dart'; // Added for TimeSlot class

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize timezone
  tz.initializeTimeZones();
  
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Productivity Assistant',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  
  // Shared data repository
  final List<Task> _tasks = [];
  final List<Task> _priorityTasks = [];
  final List<MoodEntry> _moodEntries = [];
  final List<DistractionEntry> _distractionEntries = [];
  final List<FocusSession> _focusSessions = [];
  final List<ProductivityEntry> _productivityEntries = [];
  
  // User stats
  int xp = 0;
  int streak = 0;
  int badges = 0;

  // Initialize notification plugin instance
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  @override
  void initState() {
    super.initState();
    
    // Initialize notifications
    _initializeNotifications();
    
    // Add some sample data
    _initializeSampleData();
  }

  Future<void> _initializeNotifications() async {
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
  
  void _initializeSampleData() {
    // Initialize with some dummy data for demonstration
    final now = DateTime.now();
    final random = Random();

    // Generate past 7 days of productivity data
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      _productivityEntries.add(
        ProductivityEntry(
          date: date,
          tasksCompleted: random.nextInt(8),
          focusMinutes: random.nextInt(120),
          distractionCount: random.nextInt(15),
          averageMood: 2.0 + random.nextDouble() * 3,
        )
      );
    }

    // Add some sample tasks
    _tasks.add(Task(
      title: 'Complete project proposal', 
      deadline: DateTime.now().add(const Duration(days: 2)),
      priority: 5,
      estimatedMinutes: 120,
      tags: ['Work', 'Urgent'],
    ));
    
    _tasks.add(Task(
      title: 'Buy groceries', 
      deadline: DateTime.now().add(const Duration(days: 1)),
      priority: 3,
      estimatedMinutes: 45,
      tags: ['Personal', 'Errands'],
    ));
    
    // Add some sample mood entries
    _moodEntries.add(MoodEntry(
      rating: 4,
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      sessionType: 'Focus',
    ));
    
    _moodEntries.add(MoodEntry(
      rating: 5,
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      sessionType: 'Break',
    ));
    
    // Add some sample distraction entries
    _distractionEntries.add(DistractionEntry(
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      type: 'Phone',
      durationSeconds: 120,
    ));
    
    _distractionEntries.add(DistractionEntry(
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
      type: 'Movement',
      durationSeconds: 45,
    ));
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          // Smart To-Do List Page
          SmartTodoListPage(
            tasks: _tasks,
            priorityTasks: _priorityTasks,
            onTaskAdded: (task) {
              setState(() {
                _tasks.add(task);
              });
            },
            onTaskCompleted: (index, completed) {
              setState(() {
                _tasks[index].isCompleted = completed;
                if (completed) {
                  xp += 10;
                  streak++;
                  
                  if (streak >= 5) {
                    badges++;
                    streak = 0;
                  }
                }
              });
            },
            onTaskDeleted: (index) {
              setState(() {
                _tasks.removeAt(index);
              });
            },
          ),
          
          // Focus Mode Page
          FocusModePage(
            onFocusSessionCompleted: (session) {
              setState(() {
                _focusSessions.add(session);
                xp += 25 + (session.actualDurationMinutes ?? 0);
                
                // Update mood entries
                if (session.endMood != null) {
                  _moodEntries.add(MoodEntry(
                    rating: session.endMood!,
                    timestamp: session.endTime ?? DateTime.now(),
                    sessionType: 'Focus',
                  ));
                }
                
                // Update distractions
                _distractionEntries.addAll(session.distractions);
                
                // Update daily productivity
                _updateOrCreateTodayProductivityEntry();
              });
            },
            onMoodRecorded: (moodEntry) {
              setState(() {
                _moodEntries.add(moodEntry);
              });
            },
            onDistraction: (distraction) {
              setState(() {
                _distractionEntries.add(distraction);
              });
            },
          ),
          
          // Insights Page
          InsightsPage(
            tasks: _tasks,
            moodEntries: _moodEntries,
            distractionEntries: _distractionEntries,
            focusSessions: _focusSessions,
            productivityEntries: _productivityEntries,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Focus',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.cyan,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.black,
        onTap: _onItemTapped,
      ),
      // Stats bar at bottom (optional - could move to individual pages)
      persistentFooterButtons: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          width: MediaQuery.of(context).size.width,
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
  
  void _updateOrCreateTodayProductivityEntry() {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final existingEntryIndex = _productivityEntries.indexWhere(
      (entry) => entry.date.year == today.year &&
                 entry.date.month == today.month &&
                 entry.date.day == today.day
    );
    
    // Calculate today's data
    int tasksCompletedToday = _tasks.where((task) => 
      task.isCompleted && 
      task.deadline?.year == today.year &&
      task.deadline?.month == today.month &&
      task.deadline?.day == today.day
    ).length;
    
    int focusMinutesToday = _focusSessions
      .where((session) => 
        session.startTime.year == today.year &&
        session.startTime.month == today.month &&
        session.startTime.day == today.day
      )
      .fold(0, (sum, session) => sum + (session.actualDurationMinutes ?? 0));
    
    int distractionCountToday = _distractionEntries
      .where((distraction) => 
        distraction.timestamp.year == today.year &&
        distraction.timestamp.month == today.month &&
        distraction.timestamp.day == today.day
      )
      .length;
    
    double averageMoodToday = 3.0;
    final todayMoods = _moodEntries.where((mood) => 
      mood.timestamp.year == today.year &&
      mood.timestamp.month == today.month &&
      mood.timestamp.day == today.day
    ).toList();
    
    if (todayMoods.isNotEmpty) {
      averageMoodToday = todayMoods
        .map((mood) => mood.rating)
        .reduce((a, b) => a + b) / todayMoods.length;
    }
    
    if (existingEntryIndex >= 0) {
      _productivityEntries[existingEntryIndex].tasksCompleted = tasksCompletedToday;
      _productivityEntries[existingEntryIndex].focusMinutes = focusMinutesToday;
      _productivityEntries[existingEntryIndex].distractionCount = distractionCountToday;
      _productivityEntries[existingEntryIndex].averageMood = averageMoodToday;
    } else {
      _productivityEntries.add(
        ProductivityEntry(
          date: today,
          tasksCompleted: tasksCompletedToday,
          focusMinutes: focusMinutesToday,
          distractionCount: distractionCountToday,
          averageMood: averageMoodToday,
        )
      );
    }
  }
}