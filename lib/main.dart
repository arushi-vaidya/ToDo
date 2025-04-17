import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:confetti/confetti.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:app_usage/app_usage.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:supercharged/supercharged.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'pages/smart_todo_page.dart';
import 'pages/focus_mode_page.dart';
import 'models/task.dart';
import 'models/mood_entry.dart';
import 'models/distraction_entry.dart';
import 'models/focus_session.dart';
import 'models/productivity_entry.dart';
import 'models/time_slot.dart';
import 'ai/gemini_service.dart';
import 'pages/insights_page.dart';

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

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
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
  
  // Confetti controller for celebrations
  late ConfettiController _confettiController;
  
  // Animation controllers
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize confetti controller
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    
    // Initialize glow animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
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
      id: '1',
      title: 'Complete project proposal', 
      deadline: DateTime.now().add(const Duration(days: 2)),
      priority: 5,
      estimatedMinutes: 120,
      tags: ['Work', 'Urgent'],
      isCompleted: false,
      notes: 'Include all API endpoints and data models',
    ));
    
    _tasks.add(Task(
      id: '2',
      title: 'Buy groceries', 
      deadline: DateTime.now().add(const Duration(days: 1)),
      priority: 3,
      estimatedMinutes: 45,
      tags: ['Personal', 'Errands'],
      isCompleted: false,
      notes: 'Don\'t forget milk and eggs',
    ));
    
    // Add priority task
    _priorityTasks.add(Task(
      id: '3',
      title: 'Prepare presentation for meeting',
      deadline: DateTime.now().add(const Duration(days: 1)),
      priority: 5,
      estimatedMinutes: 90,
      tags: ['Work', 'Urgent'],
      isCompleted: false,
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
    _confettiController.dispose();
    _glowController.dispose();
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
  
  void _celebrateAchievement() {
    _confettiController.play();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  Color(0xFF0A1929),
                  Colors.black,
                ],
              ),
            ),
          ),
          
          // Main content
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            children: [
              // Smart To-Do List Page
              SmartTodoPage(
                tasks: _tasks,
                priorityTasks: _priorityTasks,
                onTaskAdded: (task) {
                  setState(() {
                    if (task.priority >= 4) {
                      _priorityTasks.add(task);
                    } else {
                      _tasks.add(task);
                    }
                  });
                },
                onTaskCompleted: (taskId, completed) {
                  setState(() {
                    // Check in regular tasks
                    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
                    if (taskIndex != -1) {
                      _tasks[taskIndex] = _tasks[taskIndex].copyWith(isCompleted: completed);
                      if (completed) {
                        xp += 10;
                        streak++;
                        
                        if (streak >= 5) {
                          badges++;
                          streak = 0;
                          _celebrateAchievement(); // Show confetti for badge earned
                        }
                      }
                      return;
                    }
                    
                    // Check in priority tasks
                    final priorityTaskIndex = _priorityTasks.indexWhere((t) => t.id == taskId);
                    if (priorityTaskIndex != -1) {
                      _priorityTasks[priorityTaskIndex] = _priorityTasks[priorityTaskIndex].copyWith(isCompleted: completed);
                      if (completed) {
                        xp += 15; // More XP for priority tasks
                        streak++;
                        
                        if (streak >= 5) {
                          badges++;
                          streak = 0;
                          _celebrateAchievement(); // Show confetti for badge earned
                        }
                      }
                    }
                  });
                },
                onTaskDeleted: (taskId) {
                  setState(() {
                    _tasks.removeWhere((t) => t.id == taskId);
                    _priorityTasks.removeWhere((t) => t.id == taskId);
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
                    
                    // Celebrate long focus sessions
                    if ((session.actualDurationMinutes ?? 0) > 30) {
                      _celebrateAchievement();
                    }
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
                productivityEntries: _productivityEntries,
                moodEntries: _moodEntries,
                distractionEntries: _distractionEntries,
                focusSessions: _focusSessions,
                tasks: _tasks,
              ),
            ],
          ),
          
          // Confetti overlay for celebrations
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5,
              minBlastForce: 1,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.cyan,
              ],
            ),
          ),
          
          // Bottom stats bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                border: Border(
                  top: BorderSide(
                    color: Colors.cyan.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatsItem('XP', xp, Icons.star, Colors.amber),
                  _buildStatsItem('Streak', streak, Icons.local_fire_department, Colors.orange),
                  _buildStatsItem('Badges', badges, Icons.workspace_premium, Colors.cyan),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, -3),
              ),
            ],
            border: Border(
              top: BorderSide(
                color: Colors.cyan.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.black,
            selectedItemColor: Colors.cyan,
            unselectedItemColor: Colors.white54,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.check_circle_outline),
                label: 'Tasks',
              ),
              BottomNavigationBarItem(
                icon: AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Icon(
                      Icons.timer,
                      shadows: [
                        Shadow(
                          color: _selectedIndex == 1
                              ? Colors.cyan.withOpacity(0.5 * _glowAnimation.value)
                              : Colors.transparent,
                          blurRadius: 10 * _glowAnimation.value,
                        ),
                      ],
                    );
                  },
                ),
                label: 'Focus',
              ),
              BottomNavigationBarItem(
                icon: AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Icon(
                      Icons.insights,
                      shadows: [
                        Shadow(
                          color: _selectedIndex == 2
                              ? Colors.cyan.withOpacity(0.5 * _glowAnimation.value)
                              : Colors.transparent,
                          blurRadius: 10 * _glowAnimation.value,
                        ),
                      ],
                    );
                  },
                ),
                label: 'Insights',
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatsItem(String label, int value, IconData icon, Color color) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2 * _glowAnimation.value),
                blurRadius: 10 * _glowAnimation.value,
                spreadRadius: 1 * _glowAnimation.value,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                '$label: $value',
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
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
    
    // Add the priority tasks completed today
    tasksCompletedToday += _priorityTasks.where((task) => 
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

// Custom Painter for particles
class ParticlePainter extends CustomPainter {
  final List<Map<String, dynamic>> particles;
  
  ParticlePainter(this.particles);
  
  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = Colors.cyan.withOpacity(particle['opacity'])
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(particle['x'], particle['y']),
        particle['size'],
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom Painter for hexagons
class HexagonPainter extends CustomPainter {
  final Color color;
  
  HexagonPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * pi / 180;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Neural Network Painter for AI visualization
class NeuralNetworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42); // Fixed seed for consistent pattern
    
    // Define layers
    final layers = [4, 6, 8, 6, 4];
    final nodes = <List<Offset>>[];
    
    // Calculate node positions
    for (int i = 0; i < layers.length; i++) {
      final layerNodes = <Offset>[];
      final layerWidth = size.width / (layers.length + 1);
      final x = layerWidth * (i + 1);
      
      for (int j = 0; j < layers[i]; j++) {
        final nodeSpacing = size.height / (layers[i] + 1);
        final y = nodeSpacing * (j + 1);
        layerNodes.add(Offset(x, y));
      }
      
      nodes.add(layerNodes);
    }
    
    // Draw connections
    for (int i = 0; i < nodes.length - 1; i++) {
      for (var startNode in nodes[i]) {
        for (var endNode in nodes[i + 1]) {
          final strength = random.nextDouble();
          
          if (strength > 0.3) { // Only draw some connections for clarity
            final paint = Paint()
              ..color = Colors.cyan.withOpacity(strength * 0.3)
              ..strokeWidth = strength * 1.5;
            
            canvas.drawLine(startNode, endNode, paint);
          }
        }
      }
    }
    
    // Draw nodes
    for (int i = 0; i < nodes.length; i++) {
      for (var node in nodes[i]) {
        // Glow
        final glowPaint = Paint()
          ..color = Colors.cyan.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        
        canvas.drawCircle(node, 8, glowPaint);
        
        // Node
        final nodePaint = Paint()
          ..color = i % 2 == 0 ? Colors.cyan : Colors.purpleAccent
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(node, 4, nodePaint);
        
        // Border
        final borderPaint = Paint()
          ..color = Colors.white.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        
        canvas.drawCircle(node, 4, borderPaint);
      }
    }
    
    // Draw data flow animation
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    for (int i = 0; i < nodes.length - 1; i++) {
      for (int j = 0; j < nodes[i].length; j += 2) { // Only animate some connections
        for (int k = 0; k < nodes[i + 1].length; k += 2) {
          final startNode = nodes[i][j];
          final endNode = nodes[i + 1][k];
          
          final dx = endNode.dx - startNode.dx;
          final dy = endNode.dy - startNode.dy;
          
          // Animate dot along the line
          final speed = 0.5; // Speed of animation
          final offset = (j * k) % 5; // Offset to stagger animations
          final t = ((now * speed) + offset) % 1.0;
          
          final x = startNode.dx + dx * t;
          final y = startNode.dy + dy * t;
          
          final pulsePaint = Paint()
            ..color = Colors.white.withOpacity(0.8)
            ..style = PaintingStyle.fill;
          
          canvas.drawCircle(Offset(x, y), 2, pulsePaint);
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}