import 'package:flutter/material.dart';
import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:app_usage/app_usage.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:supercharged/supercharged.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/focus_session.dart';
import '../models/mood_entry.dart';
import '../models/distraction_entry.dart';
import '../models/time_slot.dart';

class FocusModePage extends StatefulWidget {
  final Function(FocusSession) onFocusSessionCompleted;
  final Function(MoodEntry) onMoodRecorded;
  final Function(DistractionEntry) onDistraction;
  
  const FocusModePage({
    Key? key, 
    required this.onFocusSessionCompleted, 
    required this.onMoodRecorded,
    required this.onDistraction,
  }) : super(key: key);

  @override
  State<FocusModePage> createState() => _FocusModePageState();
}

class _FocusModePageState extends State<FocusModePage> with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _isInFocusMode = false;
  int _focusDurationMinutes = 25;
  Timer? _timer;
  int _secondsRemaining = 0;
  String _sessionId = '';
  int _initialMood = 3;
  DateTime? _startTime;
  List<DistractionEntry> _distractions = [];
  
  // For distraction detection
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  Timer? _inactivityTimer;
  Timer? _usageCheckTimer;
  bool _isDistractionDialogShowing = false;
  DateTime? _lastDistractionTime;
  DateTime? _lastUserInteraction;
  int _phoneDistractions = 0;
  int _movementDistractions = 0;
  int _noiseDistractions = 0;
  int _inactivityDistractions = 0;
  String? _currentTaskTitle;
  
  // Distraction detection settings
  double _movementSensitivity = 15.0; // Default threshold
  double _noiseSensitivity = 70.0; // Default dB threshold
  int _inactivityThresholdSeconds = 120; // 2 minutes of inactivity
  bool _detectMovement = true;
  bool _detectNoise = true;
  bool _detectAppSwitch = true;
  bool _detectInactivity = true;
  bool _detectScreenTime = true;
  
  // UI animation controllers
  late AnimationController _pulseController;
  late Animation<double> _breatheAnimation;
  
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;
  
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  
  late AnimationController _particleController;
  
  // Text field controller for task input
  late TextEditingController _taskInputController;
  
  // Progress values
  double get _progress => _secondsRemaining / (_focusDurationMinutes * 60);
  
  // Noise meter
  final NoiseMeter _noiseMeter = NoiseMeter();
  
  // Particle positions
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();
  
  // Notifications
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Motivational quotes
  final List<String> _motivationalQuotes = [
    "Stay focused. Your goals are worth it.",
    "One distraction at a time is all it takes to derail your progress.",
    "Focus is not about saying yes to the task at hand, but saying no to distractions.",
    "The successful warrior is the average person with laser-like focus.",
    "Your focus determines your reality.",
    "Concentrate all your thoughts on the task at hand.",
    "Where focus goes, energy flows.",
    "Starve your distractions, feed your focus.",
    "The main thing is to keep the main thing the main thing.",
    "Focus on the journey, not the destination.",
    "Don't let what you cannot do interfere with what you can do.",
    "Lack of direction, not lack of time, is the problem. We all have 24-hour days.",
    "It's not that I'm so smart, it's just that I stay with problems longer.",
    "The more you lose yourself in something bigger than yourself, the more energy you will have.",
    "Concentrate on what matters most. There are just too many things competing for your attention.",
  ];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _taskInputController = TextEditingController();
    
    // Initialize animation controllers
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _breatheAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
    
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();
    
    _particleController.addListener(_updateParticles);
    
    // Initialize particles
    _initializeParticles();
    
    // Load distraction detection settings
    _loadDistractionSettings();
    
    // Initialize notifications
    _initializeNotifications();
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
    await _notificationsPlugin.initialize(
      initializationSettings,
    );
  }
  
  void _initializeParticles() {
    for (int i = 0; i < 30; i++) {
      _particles.add(Particle(
        position: Offset(
          _random.nextDouble() * 400 - 200,
          _random.nextDouble() * 400 - 200,
        ),
        speed: 0.5 + _random.nextDouble() * 1.5,
        radius: 1 + _random.nextDouble() * 3,
        color: [
          Colors.cyan.withOpacity(0.6),
          Colors.blue.withOpacity(0.6),
          Colors.purple.withOpacity(0.6),
          Colors.teal.withOpacity(0.6),
        ][_random.nextInt(4)],
      ));
    }
  }
  
  void _updateParticles() {
    if (!mounted) return;
    
    setState(() {
      for (var particle in _particles) {
        particle.update();
      }
    });
  }
  
  Future<void> _loadDistractionSettings() async {
    // In a real app, you would load these from SharedPreferences
    // For now, we'll just use the default values
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Detect when app is put into background (potential distraction)
    if (_isInFocusMode && _detectAppSwitch && state == AppLifecycleState.paused) {
      _recordDistraction('App Switch');
    }
    
    // When app comes back to foreground, check if other apps were used
    if (_isInFocusMode && _detectScreenTime && state == AppLifecycleState.resumed) {
      _checkRecentAppUsage();
    }
    
    // Reset inactivity timer when app state changes
    _resetInactivityTimer();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _stopDistractionDetection();
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _rotationController.dispose();
    _glowController.dispose();
    _particleController.dispose();
    _taskInputController.dispose();
    super.dispose();
  }
  
  void _startFocusSession() async {
    // Haptic feedback for better user experience
    HapticFeedback.mediumImpact();
    
    // First, ask for task selection
    await _showTaskSelectionDialog();
    
    // Then, ask for mood before starting
    await _showMoodSelectionDialog(true);
    
    // Generate a unique session ID
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Start the timer
    _secondsRemaining = _focusDurationMinutes * 60;
    _startTime = DateTime.now();
    _distractions = [];
    
    // Reset distraction counters
    _phoneDistractions = 0;
    _movementDistractions = 0;
    _noiseDistractions = 0;
    _inactivityDistractions = 0;
    
    setState(() {
      _isInFocusMode = true;
      _timer = Timer.periodic(const Duration(seconds: 1), _updateTimer);
    });
    
    // Start monitoring for distractions
    _startDistractionDetection();
    
    // Record initial mood entry
    final moodEntry = MoodEntry(
      rating: _initialMood,
      timestamp: _startTime!,
      sessionType: 'Focus',
    );
    widget.onMoodRecorded(moodEntry);
    
    // Initialize last interaction time
    _lastUserInteraction = DateTime.now();
  }
  
  void _updateTimer(Timer timer) {
    if (_secondsRemaining <= 0) {
      _endFocusSession(true);
      return;
    }
    
    setState(() {
      _secondsRemaining--;
    });
  }
  
  void _endFocusSession(bool completed) async {
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    _timer?.cancel();
    _stopDistractionDetection();
    
    // Ask for mood at end of session
    int? endMood;
    if (completed) {
      endMood = await _showMoodSelectionDialog(false);
    }
    
    // Calculate actual duration
    final now = DateTime.now();
    final actualDurationMinutes = _startTime != null
        ? now.difference(_startTime!).inMinutes
        : 0;
    
    // Create the session object
    final session = FocusSession(
      startTime: _startTime ?? now,
      endTime: now,
      plannedDurationMinutes: _focusDurationMinutes,
      actualDurationMinutes: actualDurationMinutes,
      id: _sessionId,
      initialMood: _initialMood,
      endMood: endMood,
      distractions: _distractions,
      taskWorkedOn: _currentTaskTitle,
    );
    
    // Submit the session
    widget.onFocusSessionCompleted(session);
    
    setState(() {
      _isInFocusMode = false;
      _distractions = [];
    });
    
    // Show completion dialog
    if (completed) {
      _showSessionCompletedDialog(session);
    }
  }
  
  void _startDistractionDetection() {
    // 1. Movement detection (accelerometer)
    if (_detectMovement) {
      _startMovementDetection();
    }
    
    // 2. Noise detection
    if (_detectNoise) {
      _startNoiseDetection();
    }
    
    // 3. Inactivity detection
    if (_detectInactivity) {
      _startInactivityDetection();
    }
    
    // 4. App usage detection (periodic check)
    if (_detectScreenTime) {
      _startAppUsageDetection();
    }
  }
  
  void _startMovementDetection() {
    // Listen for accelerometer changes (movement detection)
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      // Check if movement exceeds threshold
      if (_isInFocusMode && !_isDistractionDialogShowing && 
          (event.x.abs() > _movementSensitivity || 
           event.y.abs() > _movementSensitivity || 
           event.z.abs() > _movementSensitivity)) {
        // Check if this movement is recorded too frequently
        final now = DateTime.now();
        if (_lastDistractionTime == null || 
            now.difference(_lastDistractionTime!).inSeconds > 30) {
          _recordDistraction('Movement');
          _lastDistractionTime = now;
          _movementDistractions++;
        }
      }
      
      // Reset inactivity timer on significant movement
      if (event.x.abs() > 5 || event.y.abs() > 5 || event.z.abs() > 5) {
        _resetInactivityTimer();
      }
    });
  }
  
  void _startNoiseDetection() {
    try {
      _noiseSubscription = _noiseMeter.noiseStream.listen((NoiseReading noiseReading) {
        // Check if noise exceeds threshold (in dB)
        if (_isInFocusMode && !_isDistractionDialogShowing && 
            noiseReading.meanDecibel > _noiseSensitivity) {
          // Check if this noise is recorded too frequently
          final now = DateTime.now();
          if (_lastDistractionTime == null || 
              now.difference(_lastDistractionTime!).inSeconds > 30) {
            _recordDistraction('Noise');
            _lastDistractionTime = now;
            _noiseDistractions++;
          }
        }
      });
    } catch (e) {
      print('Could not start noise detection: $e');
    }
  }
  
  void _startInactivityDetection() {
    // Initialize inactivity timer
    _resetInactivityTimer();
  }
  
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _lastUserInteraction = DateTime.now();
    
    if (_isInFocusMode && _detectInactivity) {
      _inactivityTimer = Timer.periodic(Duration(seconds: _inactivityThresholdSeconds ~/ 4), (timer) {
        // Check if user has been inactive for the threshold period
        final now = DateTime.now();
        final inactiveSeconds = now.difference(_lastUserInteraction!).inSeconds;
        
        if (inactiveSeconds >= _inactivityThresholdSeconds && !_isDistractionDialogShowing) {
          _recordDistraction('Inactivity');
          _inactivityDistractions++;
          _lastUserInteraction = now; // Reset the timer
        }
      });
    }
  }
  
  void _startAppUsageDetection() {
    // Periodically check app usage (Android only)
    _usageCheckTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (_isInFocusMode && _detectScreenTime) {
        await _checkRecentAppUsage();
      }
    });
  }
  
  Future<void> _checkRecentAppUsage() async {
    try {
      // This only works on Android
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      
      if (androidInfo.version.sdkInt >= 21) { // Lollipop and above
        // Get app usage stats for the last 5 minutes
        final DateTime endDate = DateTime.now();
        final DateTime startDate = endDate.subtract(const Duration(minutes: 5));
        
        final List<AppUsageInfo> infoList = await AppUsage().getAppUsage(startDate, endDate);
        
        // Filter out our own app
        final otherAppsUsed = infoList.where((info) => 
          info.packageName != 'com.yourcompany.yourappname' && // Replace with your app's package name
          info.usage.inSeconds > 10 // Only count if used for more than 10 seconds
        ).toList();
        
        if (otherAppsUsed.isNotEmpty && !_isDistractionDialogShowing) {
          // User has been using other apps
          _recordDistraction('Screen Time');
          _phoneDistractions++;
        }
      }
    } catch (e) {
      print('Could not check app usage: $e');
    }
  }
  
  void _stopDistractionDetection() {
    // Cancel all subscriptions and timers
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    
    _noiseSubscription?.cancel();
    _noiseSubscription = null;
    
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    
    _usageCheckTimer?.cancel();
    _usageCheckTimer = null;
  }
  
  Future<void> _showMotivationalQuoteNotification(String distractionType) async {
    // Get a random motivational quote
    final quote = _motivationalQuotes[_random.nextInt(_motivationalQuotes.length)];
    
    // Create the notification details
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'focus_mode_channel',
      'Focus Mode Notifications',
      channelDescription: 'Notifications for focus mode',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    // Show the notification
    await _notificationsPlugin.show(
      0,
      'Distraction Detected: $distractionType',
      quote,
      notificationDetails,
    );
  }
  
  void _recordDistraction(String type) {
    // Don't record distractions if the dialog is already showing
    if (_isDistractionDialogShowing) return;
    
    // Haptic feedback
    HapticFeedback.heavyImpact();
    
    // Show motivational quote notification
    _showMotivationalQuoteNotification(type);
    
    setState(() {
      _isDistractionDialogShowing = true;
    });
    
    // Show distraction dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildFuturisticDialog(
        title: 'Distraction Detected',
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.redAccent,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'We detected a $type distraction. What happened?',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildGlowingProgressBar(
              colors: [Colors.redAccent, Colors.orangeAccent],
            ),
          ],
        ),
        actions: [
          _buildGlowingButton(
            text: 'Record Distraction',
            icon: Icons.check_circle_outline,
            gradient: const LinearGradient(
              colors: [Colors.cyan, Colors.blue],
            ),
            onPressed: () {
              // Create a new distraction entry
              final distraction = DistractionEntry(
                timestamp: DateTime.now(),
                type: type,
                durationSeconds: 30, // Default estimate
                sessionId: _sessionId,
              );
              
              // Add to session list
              _distractions.add(distraction);
              
              // Send to parent
              widget.onDistraction(distraction);
              
              Navigator.of(context).pop();
              setState(() {
                _isDistractionDialogShowing = false;
              });
              
              // Reset user interaction time
              _lastUserInteraction = DateTime.now();
            },
          ),
          _buildGlowingButton(
            text: 'False Alarm',
            icon: Icons.cancel_outlined,
            gradient: LinearGradient(
              colors: [Colors.grey.shade700, Colors.grey.shade900],
            ),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isDistractionDialogShowing = false;
              });
              
              // Reset user interaction time
              _lastUserInteraction = DateTime.now();
            },
          ),
        ],
      ),
    );
  }
  
  Future<void> _showTaskSelectionDialog() async {
    // Reset the controller
    _taskInputController.clear();
    
    // In a real implementation, this would show a list of tasks from the main task list
    // For now, we'll just let the user enter a task name
    String? taskName = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => _buildFuturisticDialog(
        title: 'What will you work on?',
        icon: Icons.task_alt,
        iconColor: Colors.cyan,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _taskInputController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter task name',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white10,
                prefixIcon: const Icon(Icons.edit_note, color: Colors.cyan),
              ),
              onSubmitted: (value) {
                Navigator.of(dialogContext).pop(value);
              },
            ),
            const SizedBox(height: 20),
            _buildGlowingProgressBar(
              colors: [Colors.cyan, Colors.blue],
            ),
          ],
        ),
        actions: [
          _buildGlowingButton(
            text: 'Skip',
            icon: Icons.skip_next,
            gradient: LinearGradient(
              colors: [Colors.grey.shade700, Colors.grey.shade900],
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
          _buildGlowingButton(
            text: 'Confirm',
            icon: Icons.check_circle_outline,
            gradient: const LinearGradient(
              colors: [Colors.cyan, Colors.blue],
            ),
            onPressed: () {
              // Get the value from the text controller
              Navigator.of(dialogContext).pop(_taskInputController.text);
            },
          ),
        ],
      ),
    );
    
    if (taskName != null && taskName.isNotEmpty) {
      setState(() {
        _currentTaskTitle = taskName;
      });
    }
  }
  
  Future<int?> _showMoodSelectionDialog(bool isInitial) async {
    int selectedMood = isInitial ? _initialMood : 3;
    
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return _buildFuturisticDialog(
            title: isInitial ? 'How are you feeling?' : 'How do you feel now?',
            icon: isInitial ? Icons.sentiment_satisfied_alt : Icons.psychology,
            iconColor: Colors.cyan,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Rate your current mood:',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (int i = 1; i <= 5; i++)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            selectedMood = i;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selectedMood == i 
                                ? _getMoodColor(i).withOpacity(0.2) 
                                : Colors.transparent,
                            border: Border.all(
                              color: selectedMood == i ? _getMoodColor(i) : Colors.grey,
                              width: 2,
                            ),
                            boxShadow: selectedMood == i 
                                ? [BoxShadow(
                                    color: _getMoodColor(i).withOpacity(0.5),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  )] 
                                : null,
                          ),
                          child: Text(
                            _getMoodEmoji(i),
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 25),
                Text(
                  _getMoodDescription(selectedMood),
                  style: TextStyle(
                    color: _getMoodColor(selectedMood),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _buildGlowingProgressBar(
                  colors: [_getMoodColor(1), _getMoodColor(5)],
                ),
              ],
            ),
            actions: [
              _buildGlowingButton(
                text: 'Confirm',
                icon: Icons.check_circle_outline,
                gradient: LinearGradient(
                  colors: [_getMoodColor(selectedMood), _getMoodColor(selectedMood).withOpacity(0.7)],
                ),
                onPressed: () {
                  Navigator.of(context).pop(selectedMood);
                },
              ),
            ],
          );
        },
      ),
    );
    
    if (isInitial && result != null) {
      setState(() {
        _initialMood = result;
      });
    }
    
    return result;
  }
  
  Color _getMoodColor(int mood) {
    switch (mood) {
      case 1: return Colors.redAccent;
      case 2: return Colors.orangeAccent;
      case 3: return Colors.yellow;
      case 4: return Colors.lightGreenAccent;
      case 5: return Colors.greenAccent;
      default: return Colors.yellow;
    }
  }
  
  String _getMoodEmoji(int mood) {
    switch (mood) {
      case 1: return '😞';
      case 2: return '😐';
      case 3: return '🙂';
      case 4: return '😊';
      case 5: return '😄';
      default: return '🙂';
    }
  }
  
  String _getMoodDescription(int mood) {
    switch (mood) {
      case 1: return 'Very Unhappy';
      case 2: return 'Unhappy';
      case 3: return 'Neutral';
      case 4: return 'Happy';
      case 5: return 'Very Happy';
      default: return 'Neutral';
    }
  }
  
  void _showSessionCompletedDialog(FocusSession session) {
    // Haptic feedback for completion
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      builder: (context) => _buildFuturisticDialog(
        title: 'Session Completed!',
        icon: Icons.celebration,
        iconColor: Colors.greenAccent,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.1),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, color: Colors.cyan),
                      const SizedBox(width: 10),
                      Text(
                        'You focused for ${session.actualDurationMinutes} minutes!',
                        style: const TextStyle(
                          color: Colors.black, // Adjust for white background
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem(
                        Icons.warning_amber_rounded,
                        'Distractions',
                        '${session.distractions.length}',
                        Colors.orangeAccent,
                      ),
                      if (session.taskWorkedOn != null && session.taskWorkedOn!.isNotEmpty)
                        _buildStatItem(
                          Icons.task_alt,
                          'Task',
                          session.taskWorkedOn!.length > 15
                              ? '${session.taskWorkedOn!.substring(0, 15)}...'
                              : session.taskWorkedOn!,
                          Colors.cyan,
                        ),
                    ],
                  ),
                  if (session.initialMood != null && session.endMood != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getMoodEmoji(session.initialMood),
                            style: const TextStyle(fontSize: 24),
                          ),
                          const Icon(Icons.arrow_forward, color: Colors.black54),
                          Text(
                            _getMoodEmoji(session.endMood!),
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            session.endMood! > session.initialMood
                                ? 'Mood improved!'
                                : session.endMood! < session.initialMood
                                    ? 'Mood decreased'
                                    : 'Mood unchanged',
                            style: TextStyle(
                              color: session.endMood! > session.initialMood
                                  ? Colors.greenAccent
                                  : session.endMood! < session.initialMood
                                      ? Colors.redAccent
                                      : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildGlowingProgressBar(
              colors: [Colors.greenAccent, Colors.cyan],
            ),
          ],
        ),
        actions: [
          _buildGlowingButton(
            text: 'Awesome!',
            icon: Icons.celebration,
            gradient: const LinearGradient(
              colors: [Colors.greenAccent, Colors.cyan],
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: color, fontSize: 12)),
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
  
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        // Detect user interaction to reset inactivity timer
        onTap: _resetInactivityTimer,
        onPanUpdate: (_) => _resetInactivityTimer(),
        child: Container(
          decoration: BoxDecoration(
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
          child: Stack(
            children: [
              // Particle background
              CustomPaint(
                painter: ParticlePainter(_particles),
                size: Size.infinite,
              ),
              
              // Rotating background elements
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Opacity(
                        opacity: 0.1,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [Colors.transparent, Colors.cyan.withOpacity(0.2)],
                              stops: const [0.7, 1.0],
                            ),
                          ),
                          child: CustomPaint(
                            painter: GridPainter(),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Main content
              SafeArea(
                child: Column(
                  children: [
                    // App bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'QUANTUM FOCUS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.history, color: Colors.cyan),
                                tooltip: 'Session History',
                                onPressed: () {
                                  // Show session history (to be implemented)
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.settings, color: Colors.cyan),
                                tooltip: 'Focus Settings',
                                onPressed: _showFocusSettingsDialog,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Main content
                    Expanded(
                      child: Center(
                        child: _isInFocusMode
                            ? _buildFocusActiveUI()
                            : _buildFocusInactiveUI(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFocusActiveUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Task being worked on
        if (_currentTaskTitle != null && _currentTaskTitle!.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.cyan.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.task_alt, color: Colors.cyan),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Working on: $_currentTaskTitle',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
        const SizedBox(height: 20),
          
        // Timer display with animated progress
        Stack(
          alignment: Alignment.center,
          children: [
            // Rotating outer ring
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: -_rotationAnimation.value * 0.5,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.cyan.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: CustomPaint(
                      painter: DashedCirclePainter(
                        color: Colors.cyan.withOpacity(0.3),
                        dashes: 20,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            // Outer glow
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(0.2 * _glowAnimation.value),
                        blurRadius: 30 * _glowAnimation.value,
                        spreadRadius: 5 * _glowAnimation.value,
                      ),
                    ],
                  ),
                );
              },
            ),
            
            // Progress circle
            SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                      border: Border.all(
                        color: Colors.cyan.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  
                  // Progress indicator
                  ShaderMask(
                    shaderCallback: (rect) {
                      return SweepGradient(
                        startAngle: -math.pi / 2,
                        endAngle: 3 * math.pi / 2,
                        colors: [
                          _secondsRemaining < 60 ? Colors.redAccent : Colors.cyan,
                          _secondsRemaining < 60 ? Colors.red : Colors.blue,
                        ],
                        stops: const [0.0, 1.0],
                      ).createShader(rect);
                    },
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(_progress),
                      ),
                    ),
                  ),
                  
                  // Progress circle border
                  CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 8,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _secondsRemaining < 60 ? Colors.redAccent : Colors.cyan,
                    ),
                  ),
                ],
              ),
            ),
            
            // Inner circle with time
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0A1929),
                    Colors.black,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: Colors.cyan.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'FOCUS TIME',
                      style: TextStyle(
                        color: Colors.cyan, 
                        fontSize: 16,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        return Text(
                          _formatTime(_secondsRemaining),
                          style: TextStyle(
                            color: _secondsRemaining < 60 ? Colors.redAccent : Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: (_secondsRemaining < 60 
                                    ? Colors.redAccent 
                                    : Colors.cyan).withOpacity(0.5 * _glowAnimation.value),
                                blurRadius: 10 * _glowAnimation.value,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'of $_focusDurationMinutes min',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 40),
        
        // Distraction counters
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'DISTRACTION MONITOR',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDistractionsCounter('Phone', _phoneDistractions, Icons.smartphone),
                  _buildDistractionsCounter('Movement', _movementDistractions, Icons.directions_run),
                  _buildDistractionsCounter('Noise', _noiseDistractions, Icons.volume_up),
                  _buildDistractionsCounter('Inactivity', _inactivityDistractions, Icons.hourglass_empty),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // End session
            _buildHexagonButton(
              icon: Icons.stop_circle,
              text: 'END SESSION',
              gradient: LinearGradient(
                colors: [Colors.redAccent, Colors.red.shade900],
              ),
              onPressed: () => _endFocusSession(false),
            ),
            
            const SizedBox(width: 20),
            
            // Manually record distraction button
            _buildHexagonButton(
              icon: Icons.notification_important,
              text: 'RECORD DISTRACTION',
              gradient: LinearGradient(
                colors: [Colors.orange.withOpacity(0.8), Colors.deepOrange.shade900],
              ),
              onPressed: () => _showManualDistractionDialog(),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildDistractionsCounter(String label, int count, IconData icon) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: count > 0 ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: count > 0 ? Colors.orange : Colors.grey,
                  width: 2,
                ),
                boxShadow: count > 0 ? [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.2 * _glowAnimation.value),
                    blurRadius: 10 * _glowAnimation.value,
                    spreadRadius: 1 * _glowAnimation.value,
                  ),
                ] : null,
              ),
              child: Icon(
                icon,
                color: count > 0 ? Colors.orange : Colors.grey,
                size: 24,
              ),
            );
          },
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
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildFocusInactiveUI() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          
          // Focus mode icon with animation
          AnimatedBuilder(
            animation: _breatheAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _breatheAnimation.value,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.cyan, Colors.blue],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Rotating inner elements
                      AnimatedBuilder(
                        animation: _rotationAnimation,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _rotationAnimation.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const Icon(
                        Icons.psychology,
                        size: 80,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 40),
          
          // Title with animated gradient
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.cyan, Colors.blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: const Text(
              'QUANTUM FOCUS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Description
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.cyan.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Text(
              'Our AI-powered focus assistant automatically detects distractions like movement, noise, phone usage, and inactivity to help you stay on track.',
              style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 55),
          
          // Timer selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.cyan.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'SELECT FOCUS DURATION',
                  style: TextStyle(
                    color: Colors.cyan,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SleekCircularSlider(
                  appearance: CircularSliderAppearance(
                    size: 200,
                    startAngle: 270,
                    angleRange: 360,
                    customWidths: CustomSliderWidths(
                      trackWidth: 10,
                      progressBarWidth: 10,
                      handlerSize: 15,
                    ),
                    customColors: CustomSliderColors(
                      trackColor: Colors.grey.shade800,
                      progressBarColors: [Colors.cyan, Colors.blue],
                      hideShadow: false,
                      shadowColor: Colors.cyan.withOpacity(0.2),
                      shadowMaxOpacity: 0.2,
                      shadowStep: 10,
                      gradientStartAngle: 0,
                      gradientEndAngle: 360,
                    ),
                    infoProperties: InfoProperties(
                      mainLabelStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                      modifier: (double value) {
                        final minutes = value.round();
                        return '$minutes min';
                      },
                    ),
                  ),
                  min: 5,
                  max: 120,
                  initialValue: _focusDurationMinutes.toDouble(),
                  onChange: (double value) {
                    setState(() {
                      _focusDurationMinutes = value.round();
                    });
                    HapticFeedback.selectionClick();
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  'Recommended: 25 min (Pomodoro)',
                  style: TextStyle(color: Colors.cyan.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Start button
          Container(
            margin: const EdgeInsets.only(bottom: 80), // Increased from 30 to 80 to provide more space
            child: _buildHexagonButton(
              icon: Icons.play_arrow,
              text: 'START FOCUS SESSION',
              gradient: const LinearGradient(
                colors: [Colors.cyan, Colors.blue],
              ),
              size: 1.5,
              onPressed: _startFocusSession,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHexagonButton({
    required IconData icon,
    required String text,
    required LinearGradient gradient,
    required VoidCallback onPressed,
    double size = 1.0,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: 8 * size,
              vertical: 5 * size,
            ),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(15 * size),
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.5 * _glowAnimation.value),
                  blurRadius: 15 * _glowAnimation.value,
                  spreadRadius: 1 * _glowAnimation.value,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 24 * size,
                ),
                SizedBox(width: 8 * size),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14 * size,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  void _showFocusSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return _buildFuturisticDialog(
            title: 'Focus Settings',
            icon: Icons.settings,
            iconColor: Colors.cyan,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Distraction Detection Settings',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  
                  // Movement sensitivity
                  if (_detectMovement)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.directions_run, color: Colors.cyan, size: 16),
                            const SizedBox(width: 5),
                            const Text('Movement Sensitivity:', style: TextStyle(color: Colors.white70)),
                            const Spacer(),
                            Text(
                              _movementSensitivity.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.cyan),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: Colors.cyan,
                            inactiveTrackColor: Colors.grey.shade800,
                            thumbColor: Colors.white,
                            overlayColor: Colors.cyan.withOpacity(0.2),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                          ),
                          child: Slider(
                            value: _movementSensitivity,
                            min: 5.0,
                            max: 25.0,
                            onChanged: (value) {
                              setState(() {
                                _movementSensitivity = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  
                  // Noise sensitivity
                  if (_detectNoise)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.volume_up, color: Colors.cyan, size: 16),
                            const SizedBox(width: 5),
                            const Text('Noise Sensitivity (dB):', style: TextStyle(color: Colors.white70)),
                            const Spacer(),
                            Text(
                              _noiseSensitivity.toStringAsFixed(0),
                              style: const TextStyle(color: Colors.cyan),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: Colors.cyan,
                            inactiveTrackColor: Colors.grey.shade800,
                            thumbColor: Colors.white,
                            overlayColor: Colors.cyan.withOpacity(0.2),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                          ),
                          child: Slider(
                            value: _noiseSensitivity,
                            min: 50.0,
                            max: 100.0,
                            onChanged: (value) {
                              setState(() {
                                _noiseSensitivity = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  
                  // Inactivity threshold
                  if (_detectInactivity)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.hourglass_empty, color: Colors.cyan, size: 16),
                            const SizedBox(width: 5),
                            const Text('Inactivity Threshold (sec):', style: TextStyle(color: Colors.white70)),
                            const Spacer(),
                            Text(
                              _inactivityThresholdSeconds.toString(),
                              style: const TextStyle(color: Colors.cyan),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: Colors.cyan,
                            inactiveTrackColor: Colors.grey.shade800,
                            thumbColor: Colors.white,
                            overlayColor: Colors.cyan.withOpacity(0.2),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                          ),
                          child: Slider(
                            value: _inactivityThresholdSeconds.toDouble(),
                            min: 60.0,
                            max: 300.0,
                            divisions: 8,
                            onChanged: (value) {
                              setState(() {
                                _inactivityThresholdSeconds = value.toInt();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 15),
                  
                  // Detection toggles
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.cyan.withOpacity(0.3), width: 1),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Row(
                            children: [
                              Icon(Icons.directions_run, color: Colors.cyan, size: 20),
                              SizedBox(width: 10),
                              Text('Movement Detection', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          value: _detectMovement,
                          onChanged: (value) {
                            setState(() {
                              _detectMovement = value;
                            });
                          },
                          activeColor: Colors.cyan,
                        ),
                        Divider(color: Colors.grey.shade800, height: 1),
                        SwitchListTile(
                          title: const Row(
                            children: [
                              Icon(Icons.volume_up, color: Colors.cyan, size: 20),
                              SizedBox(width: 10),
                              Text('Noise Detection', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          value: _detectNoise,
                          onChanged: (value) {
                            setState(() {
                              _detectNoise = value;
                            });
                          },
                          activeColor: Colors.cyan,
                        ),
                        Divider(color: Colors.grey.shade800, height: 1),
                        SwitchListTile(
                          title: const Row(
                            children: [
                              Icon(Icons.phone_android, color: Colors.cyan, size: 20),
                              SizedBox(width: 10),
                              Text('App Switch Detection', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          value: _detectAppSwitch,
                          onChanged: (value) {
                            setState(() {
                              _detectAppSwitch = value;
                            });
                          },
                          activeColor: Colors.cyan,
                        ),
                        Divider(color: Colors.grey.shade800, height: 1),
                        SwitchListTile(
                          title: const Row(
                            children: [
                              Icon(Icons.hourglass_empty, color: Colors.cyan, size: 20),
                              SizedBox(width: 10),
                              Text('Inactivity Detection', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          value: _detectInactivity,
                          onChanged: (value) {
                            setState(() {
                              _detectInactivity = value;
                            });
                          },
                          activeColor: Colors.cyan,
                        ),
                        Divider(color: Colors.grey.shade800, height: 1),
                        SwitchListTile(
                          title: const Row(
                            children: [
                              Icon(Icons.screen_lock_portrait, color: Colors.cyan, size: 20),
                              SizedBox(width: 10),
                              Text('Screen Time Detection', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          value: _detectScreenTime,
                          onChanged: (value) {
                            setState(() {
                              _detectScreenTime = value;
                            });
                          },
                          activeColor: Colors.cyan,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              _buildGlowingButton(
                text: 'Save',
                icon: Icons.save,
                gradient: const LinearGradient(
                  colors: [Colors.cyan, Colors.blue],
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  // In a real app, you would save these settings to SharedPreferences
                },
              ),
            ],
          );
        },
      ),
    );
  }
  
  void _showManualDistractionDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildFuturisticDialog(
        title: 'Record Distraction',
        icon: Icons.notification_important,
        iconColor: Colors.orange,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'What type of distraction happened?',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildDistractionButton('Phone', Icons.smartphone),
            const SizedBox(height: 10),
            _buildDistractionButton('Conversation', Icons.chat_bubble),
            const SizedBox(height: 10),
            _buildDistractionButton('Mental Wandering', Icons.psychology),
            const SizedBox(height: 10),
            _buildDistractionButton('Environmental', Icons.volume_up),
            const SizedBox(height: 15),
            _buildGlowingProgressBar(
              colors: [Colors.orange, Colors.deepOrange],
            ),
          ],
        ),
        actions: [
          _buildGlowingButton(
            text: 'Cancel',
            icon: Icons.close,
            gradient: LinearGradient(
              colors: [Colors.grey.shade700, Colors.grey.shade900],
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildDistractionButton(String type, IconData icon) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[800],
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        minimumSize: const Size(double.infinity, 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, color: Colors.orange),
      label: Text(type, style: const TextStyle(color: Colors.white)),
      onPressed: () {
        Navigator.of(context).pop();
        _recordDistraction(type);
      },
    );
  }
  
  Widget _buildFuturisticDialog({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget content,
    required List<Widget> actions,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFF0A1929),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.cyan.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(color: iconColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            content,
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGlowingButton({
    required String text,
    required IconData icon,
    required LinearGradient gradient,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: gradient.colors.first.withOpacity(0.5 * _glowAnimation.value),
                  blurRadius: 10 * _glowAnimation.value,
                  spreadRadius: 1 * _glowAnimation.value,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildGlowingProgressBar({
    required List<Color> colors,
  }) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          height: 5,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.5 * _glowAnimation.value),
                blurRadius: 10 * _glowAnimation.value,
                spreadRadius: 1 * _glowAnimation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class Particle {
  Offset position;
  double speed;
  double radius;
  Color color;
  double direction = 0;
  
  Particle({
    required this.position,
    required this.speed,
    required this.radius,
    required this.color,
  }) {
    direction = math.Random().nextDouble() * 2 * math.pi;
  }
  
  void update() {
    // Update direction slightly for more natural movement
    direction += (math.Random().nextDouble() - 0.5) * 0.2;
    
    // Update position based on direction and speed
    position = Offset(
      position.dx + math.cos(direction) * speed,
      position.dy + math.sin(direction) * speed,
    );
    
    // Wrap around edges
    if (position.dx < -200) position = Offset(200, position.dy);
    if (position.dx > 200) position = Offset(-200, position.dy);
    if (position.dy < -200) position = Offset(position.dx, 200);
    if (position.dy > 200) position = Offset(position.dx, -200);
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  
  ParticlePainter(this.particles);
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        center + particle.position,
        particle.radius,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    
    // Draw concentric circles
    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(
        center,
        radius * i / 5,
        paint,
      );
    }
    
    // Draw radial lines
    for (int i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      canvas.drawLine(
        center,
        center + Offset(radius * math.cos(angle), radius * math.sin(angle)),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashedCirclePainter extends CustomPainter {
  final Color color;
  final int dashes;
  
  DashedCirclePainter({
    required this.color,
    required this.dashes,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    
    final dashLength = 2 * math.pi * radius / (dashes * 2);
    
    for (int i = 0; i < dashes; i++) {
      final startAngle = i * 2 * math.pi / dashes;
      final endAngle = startAngle + math.pi / dashes;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
        false,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
