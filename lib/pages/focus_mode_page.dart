import 'package:flutter/material.dart';
import 'dart:async';
// For the sensors, you need to add this to pubspec.yaml:
// dependencies:
//   sensors_plus: ^latest_version
import 'package:sensors_plus/sensors_plus.dart';

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

class _FocusModePageState extends State<FocusModePage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
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
  bool _isDistractionDialogShowing = false;
  DateTime? _lastDistractionTime;
  int _phoneDistractions = 0;
  int _movementDistractions = 0;
  String? _currentTaskTitle;
  
  // UI animation controller
  late AnimationController _pulseController;
  // Text field controller for task input
  late TextEditingController _taskInputController;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _taskInputController = TextEditingController();
    
    // Initialize animation controller in initState
    _pulseController = AnimationController(
      vsync: this, // Use 'this' as the TickerProvider
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Detect when app is put into background (potential distraction)
    if (_isInFocusMode && state == AppLifecycleState.paused) {
      _recordDistraction('App Switch');
    }
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _accelerometerSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _taskInputController.dispose();
    super.dispose();
  }
  
  void _startFocusSession() async {
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
    // Listen for accelerometer changes (movement detection)
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      // Basic threshold for significant movement
      if (_isInFocusMode && !_isDistractionDialogShowing && 
          (event.x.abs() > 15 || event.y.abs() > 15 || event.z.abs() > 15)) {
        // Check if this movement is recorded too frequently
        final now = DateTime.now();
        if (_lastDistractionTime == null || 
            now.difference(_lastDistractionTime!).inSeconds > 30) {
          _recordDistraction('Movement');
          _lastDistractionTime = now;
        }
      }
    });
  }
  
  void _stopDistractionDetection() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }
  
  void _recordDistraction(String type) {
    // Don't record distractions if the dialog is already showing
    if (_isDistractionDialogShowing) return;
    
    setState(() {
      _isDistractionDialogShowing = true;
    });
    
    // Update distraction counts
    if (type == 'Phone') {
      _phoneDistractions++;
    } else if (type == 'Movement') {
      _movementDistractions++;
    }
    
    // Show distraction dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Distraction Detected', style: TextStyle(color: Colors.redAccent)),
        content: Text(
          'We noticed a $type distraction. What happened?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
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
            },
            child: const Text('Record Distraction', style: TextStyle(color: Colors.cyan)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isDistractionDialogShowing = false;
              });
            },
            child: const Text('False Alarm', style: TextStyle(color: Colors.grey)),
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
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('What will you work on?', style: TextStyle(color: Colors.cyan)),
        content: TextField(
          controller: _taskInputController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter task name',
            hintStyle: TextStyle(color: Colors.grey),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white10,
          ),
          onSubmitted: (value) {
            Navigator.of(dialogContext).pop(value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Skip', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              // Get the value from the text controller
              Navigator.of(dialogContext).pop(_taskInputController.text);
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.cyan)),
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
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text(
              isInitial ? 'How are you feeling?' : 'How do you feel now?',
              style: const TextStyle(color: Colors.cyan),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Rate your current mood:',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 20),
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
                            shape: BoxShape.circle,
                            color: selectedMood == i ? Colors.cyan : Colors.transparent,
                            border: Border.all(
                              color: selectedMood == i ? Colors.cyan : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            _getMoodEmoji(i),
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  _getMoodDescription(selectedMood),
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(selectedMood);
                },
                child: const Text('Confirm', style: TextStyle(color: Colors.cyan)),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Session Completed!', style: TextStyle(color: Colors.green)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You focused for ${session.actualDurationMinutes} minutes!',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Distractions: ${session.distractions.length}',
              style: const TextStyle(color: Colors.white70),
            ),
            if (session.initialMood != null && session.endMood != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Mood change: ${_getMoodEmoji(session.initialMood)} → ${_getMoodEmoji(session.endMood!)}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close', style: TextStyle(color: Colors.cyan)),
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
      appBar: AppBar(
        title: const Text('Focus Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Session History',
            onPressed: () {
              // Show session history (to be implemented)
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Focus Settings',
            onPressed: _showFocusSettingsDialog,
          ),
        ],
      ),
      body: Center(
        child: _isInFocusMode
            ? _buildFocusActiveUI()
            : _buildFocusInactiveUI(),
      ),
    );
  }
  
  Widget _buildFocusActiveUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Task being worked on
        if (_currentTaskTitle != null && _currentTaskTitle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Working on: $_currentTaskTitle',
              style: const TextStyle(color: Colors.white70, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
          
        // Timer display
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[900],
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'FOCUS TIME',
                  style: TextStyle(color: Colors.cyan, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  _formatTime(_secondsRemaining),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
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
        
        const SizedBox(height: 40),
        
        // Distraction counters
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDistractionsCounter('Phone', _phoneDistractions, Icons.smartphone),
            const SizedBox(width: 20),
            _buildDistractionsCounter('Movement', _movementDistractions, Icons.directions_run),
          ],
        ),
        
        const SizedBox(height: 40),
        
        // End session button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          icon: const Icon(Icons.stop_circle),
          label: const Text('End Session'),
          onPressed: () => _endFocusSession(false),
        ),
        
        // Manually record distraction button
        TextButton.icon(
          icon: const Icon(Icons.notification_important, color: Colors.orange),
          label: const Text('Record Distraction', style: TextStyle(color: Colors.orange)),
          onPressed: () => _showManualDistractionDialog(),
        ),
      ],
    );
  }
  
  Widget _buildDistractionsCounter(String label, int count, IconData icon) {
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
  
  Widget _buildFocusInactiveUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Focus mode icon
        ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.1).animate(_pulseController),
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.cyan, Colors.blue.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.psychology,
              size: 80,
              color: Colors.white,
            ),
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Title
        const Text(
          'Focus Mode',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Description
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Eliminate distractions and focus on your important tasks. We\'ll help you track your focus sessions and detect distractions.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Duration selector
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDurationOption(25),
            _buildDurationOption(45),
            _buildDurationOption(60),
            _buildDurationOption(90),
          ],
        ),
        
        const SizedBox(height: 40),
        
        // Start button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyan,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          icon: const Icon(Icons.play_arrow),
          label: const Text(
            'START FOCUS SESSION',
            style: TextStyle(fontSize: 18),
          ),
          onPressed: _startFocusSession,
        ),
      ],
    );
  }
  
  Widget _buildDurationOption(int minutes) {
    final isSelected = _focusDurationMinutes == minutes;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _focusDurationMinutes = minutes;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyan : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.cyan : Colors.grey,
            width: 2,
          ),
        ),
        child: Text(
          '$minutes min',
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  void _showFocusSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Focus Settings', style: TextStyle(color: Colors.cyan)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distraction Detection Sensitivity:',
              style: TextStyle(color: Colors.white70),
            ),
            Slider(
              value: 0.7, // Default value
              onChanged: (value) {
                // Update sensitivity settings
              },
              activeColor: Colors.cyan,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Movement Detection', style: TextStyle(color: Colors.white)),
              value: true, // Default value
              onChanged: (value) {
                // Update movement detection settings
              },
              activeColor: Colors.cyan,
            ),
            SwitchListTile(
              title: const Text('Enable App Switch Detection', style: TextStyle(color: Colors.white)),
              value: true, // Default value
              onChanged: (value) {
                // Update app switch detection settings
              },
              activeColor: Colors.cyan,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
  }
  
  void _showManualDistractionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Record Distraction', style: TextStyle(color: Colors.cyan)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'What type of distraction happened?',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            _buildDistractionButton('Phone', Icons.smartphone),
            const SizedBox(height: 8),
            _buildDistractionButton('Conversation', Icons.chat_bubble),
            const SizedBox(height: 8),
            _buildDistractionButton('Mental Wandering', Icons.psychology),
            const SizedBox(height: 8),
            _buildDistractionButton('Environmental', Icons.volume_up),
          ],
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
  
  Widget _buildDistractionButton(String type, IconData icon) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[800],
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        minimumSize: const Size(double.infinity, 0),
      ),
      icon: Icon(icon),
      label: Text(type),
      onPressed: () {
        Navigator.of(context).pop();
        _recordDistraction(type);
      },
    );
  }
}

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