import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:supercharged/supercharged.dart';
import 'package:flutter/material.dart';


import 'package:todo/models/productivity_entry.dart';
import 'package:todo/models/mood_entry.dart';
import 'package:todo/models/distraction_entry.dart';
import 'package:todo/models/focus_session.dart';
import 'package:todo/models/task.dart';
import 'package:todo/ai/gemini_service.dart';


// Custom Painter classes are imported from main.dart
import 'package:todo/main.dart' show ParticlePainter, HexagonPainter, NeuralNetworkPainter;

class InsightsPage extends StatefulWidget {
  final List<ProductivityEntry> productivityEntries;
  final List<MoodEntry> moodEntries;
  final List<DistractionEntry> distractionEntries;
  final List<FocusSession> focusSessions;
  final List<Task> tasks;
  
  const InsightsPage({
    Key? key, 
    required this.productivityEntries,
    required this.moodEntries,
    required this.distractionEntries,
    required this.focusSessions,
    required this.tasks,
  }) : super(key: key);

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  String _aiInsights = 'Loading AI insights...';
  final _geminiService = GeminiService();
  
  // Animation properties
  final _tween = MovieTween()
    ..tween('backgroundGradient1', ColorTween(begin: const Color(0xFF0B0F1A), end: const Color(0xFF0A1929)), duration: 3.seconds)
    ..tween('backgroundGradient2', ColorTween(begin: const Color(0xFF0A1929), end: const Color(0xFF050A14)), duration: 3.seconds)
    ..tween('glowOpacity', Tween<double>(begin: 0.2, end: 0.5), duration: 2.seconds)
    ..tween('glowSize', Tween<double>(begin: 30.0, end: 50.0), duration: 2.seconds);
  
  // Particle animation
  List<Map<String, dynamic>> _particles = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Initialize particles with a delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeParticles();
      // Start particle animation
      _animateParticles();
      // Generate AI insights
      _generateAiInsights();
    });
  }
  
  void _initializeParticles() {
    final random = Random();
    final size = MediaQuery.of(context).size;
    
    for (int i = 0; i < 30; i++) {
      _particles.add({
        'x': random.nextDouble() * size.width,
        'y': random.nextDouble() * size.height,
        'size': random.nextDouble() * 3 + 1,
        'speed': random.nextDouble() * 0.5 + 0.2,
        'opacity': random.nextDouble() * 0.5 + 0.1,
      });
    }
  }
  
  void _animateParticles() {
    if (!mounted) return;
    
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          final random = Random();
          final size = MediaQuery.of(context).size;
          
          for (var particle in _particles) {
            particle['y'] = (particle['y'] - particle['speed']) % size.height;
            particle['opacity'] = (particle['opacity'] + (random.nextDouble() * 0.02 - 0.01))
                .clamp(0.1, 0.6);
          }
        });
        _animateParticles();
      }
    });
  }

  Future<void> _generateAiInsights() async {
    if (!mounted) return;
    
    final prompt = '''
      Analyze the following productivity data and provide personalized insights and recommendations in a structured format:

      **Productivity Overview:**
      - Tasks completed: ${widget.tasks.where((task) => task.isCompleted).length}
      - Total tasks: ${widget.tasks.length}
      - Focus sessions: ${widget.focusSessions.length}
      - Total focus minutes: ${widget.productivityEntries.fold(0, (sum, entry) => sum + entry.focusMinutes)}

      **Distraction Analysis:**
      - Total distractions: ${widget.distractionEntries.length}
      - Average distraction duration: ${widget.distractionEntries.isNotEmpty ? widget.distractionEntries.map((e) => e.durationSeconds).reduce((a, b) => a + b) / widget.distractionEntries.length : 0} seconds

      **Mood Assessment:**
      - Average mood: ${widget.moodEntries.isNotEmpty ? widget.moodEntries.map((e) => e.rating).reduce((a, b) => a + b) / widget.moodEntries.length : 0} (on a scale of 1-5)

      **Recent Tasks:**
      - ${widget.tasks.take(5).map((task) => task.title).join(', ')}

      **Instructions:**

      1.  Provide a concise summary of the user's productivity patterns.
      2.  Identify key areas for improvement in productivity, focus, and well-being.
      3.  Offer 2-3 actionable recommendations based on the data.
      4.  Format the response using Markdown headings, bullet points, and concise sentences.
      5.  Keep the entire response under 200 words.
      ''';

    try {
      final insights = await _geminiService.generateInsights(prompt);
      if (mounted) {
        setState(() {
          _aiInsights = insights;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiInsights = "Unable to generate insights at this time. Please try again later.";
        });
      }
    }
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          PlayAnimationBuilder<Movie>(
            tween: _tween,
            duration: 3.seconds,
            builder: (context, value, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      value.get('backgroundGradient1'),
                      value.get('backgroundGradient2'),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Particle effect
          if (_particles.isNotEmpty)
            CustomPaint(
              size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
              painter: ParticlePainter(_particles),
            ),
          
          // Glow effects
          Positioned(
            top: -100,
            right: -100,
            child: PlayAnimationBuilder<Movie>(
              tween: _tween,
              duration: 2.seconds,
              builder: (context, value, child) {
                return Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(value.get('glowOpacity')),
                        blurRadius: value.get('glowSize'),
                        spreadRadius: value.get('glowSize') / 2,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          Positioned(
            bottom: -80,
            left: -80,
            child: PlayAnimationBuilder<Movie>(
              tween: _tween,
              duration: 2.seconds,
              builder: (context, value, child) {
                return Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(value.get('glowOpacity') - 0.1),
                        blurRadius: value.get('glowSize') - 10,
                        spreadRadius: (value.get('glowSize') - 10) / 2,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Main content
          Column(
            children: [
              // Custom app bar
              _buildFuturisticAppBar(),
              
              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.cyan.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: Colors.cyan.withOpacity(0.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  labelColor: Colors.cyan,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    _buildAnimatedTab(Icons.analytics_outlined, 'Productivity'),
                    _buildAnimatedTab(Icons.warning_amber_outlined, 'Distractions'),
                    _buildAnimatedTab(Icons.mood, 'Mood'),
                    _buildAnimatedTab(Icons.psychology_alt_outlined, 'AI Insights'),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0),
              
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(), // Prevent swiping to fix sliver error
                  children: [
                    _buildProductivityTab(),
                    _buildDistractionsTab(),
                    _buildMoodTab(),
                    _buildAiInsightsTab(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildFuturisticAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        border: Border(
          bottom: BorderSide(
            color: Colors.cyan.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.6),
              border: Border.all(
                color: Colors.cyan.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.insights,
              color: Colors.cyan,
              size: 24,
            ),
          ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
          const SizedBox(width: 12),
          Text(
            'INSIGHTS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              shadows: [
                Shadow(
                  color: Colors.cyan.withOpacity(0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2, end: 0),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.cyan.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Colors.cyan,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM d, yyyy').format(DateTime.now()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 800.ms).slideX(begin: 0.2, end: 0),
        ],
      ),
    );
  }
  
  Widget _buildAnimatedTab(IconData icon, String label) {
    return Tab(
      height: 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
  
  Widget _buildProductivityTab() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductivitySummary(),
            const SizedBox(height: 24),
            _buildFocusMinutesSection(),
            const SizedBox(height: 24),
            _buildProductivityByTimeSection(),
            const SizedBox(height: 24),
            _buildRecommendationsSection(),
            const SizedBox(height: 80), // Bottom padding for scrolling
          ],
        ),
      ),
    );
  }
  
  Widget _buildProductivitySummary() {
    // Calculate weekly productivity stats
    final weeklyFocusMinutes = widget.productivityEntries.fold(0, (sum, entry) => sum + entry.focusMinutes);
    final weeklyTasksCompleted = widget.productivityEntries.fold(0, (sum, entry) => sum + entry.tasksCompleted);

    // Find most productive day
    ProductivityEntry? mostProductiveDay;
    if (widget.productivityEntries.isNotEmpty) {
      mostProductiveDay = widget.productivityEntries.reduce((a, b) =>
      a.focusMinutes > b.focusMinutes ? a : b);
    }

    // Find most productive hour of day
    final hourlyProductivityMap = <int, int>{};
    for (var session in widget.focusSessions) {
      final hour = session.startTime.hour;
      hourlyProductivityMap[hour] = (hourlyProductivityMap[hour] ?? 0) +
          (session.actualDurationMinutes ?? 0);
    }

    int? mostProductiveHour;
    int maxMinutes = 0;
    hourlyProductivityMap.forEach((hour, minutes) {
      if (minutes > maxMinutes) {
        maxMinutes = minutes;
        mostProductiveHour = hour;
      }
    });
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.cyan.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Colors.cyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'PRODUCTIVITY METRICS',
                  style: TextStyle(
                    color: Colors.cyan,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHexagonalStat(
                      'Focus Minutes',
                      weeklyFocusMinutes.toString(),
                      Icons.timer,
                      Colors.cyan,
                    ),
                    _buildHexagonalStat(
                      'Tasks Completed',
                      weeklyTasksCompleted.toString(),
                      Icons.task_alt,
                      Colors.greenAccent,
                    ),
                    _buildHexagonalStat(
                      'Focus Sessions',
                      widget.focusSessions.length.toString(),
                      Icons.psychology,
                      Colors.purpleAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
               if (mostProductiveHour != null)
  _buildInfoRow(
    'Peak productivity hour',
    mostProductiveHour! > 12
        ? '${mostProductiveHour! - 12}${mostProductiveHour! >= 12 ? 'PM' : 'AM'} - $maxMinutes min'
        : '${mostProductiveHour == 0 ? 12 : mostProductiveHour}${mostProductiveHour! >= 12 ? 'PM' : 'AM'} - $maxMinutes min',
    '', // If you don't have a subtitle, just pass an empty string
    Icons.access_time,
  )



              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildFocusMinutesSection() {
    final entries = widget.productivityEntries.toList();
    entries.sort((a, b) => a.date.compareTo(b.date));
    final last7Entries = entries.length > 7 ? entries.sublist(entries.length - 7) : entries;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.cyan.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bar_chart,
                    color: Colors.cyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'DAILY FOCUS MINUTES',
                  style: TextStyle(
                    color: Colors.cyan,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 220,
              child: widget.productivityEntries.isEmpty
                  ? _buildEmptyState('No focus data available yet')
                  : _buildFocusMinutesChart(last7Entries),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildProductivityByTimeSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.cyan.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Colors.cyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'PRODUCTIVITY BY TIME OF DAY',
                  style: TextStyle(
                    color: Colors.cyan,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 220,
              child: widget.focusSessions.isEmpty
                  ? _buildEmptyState('No focus session data available yet')
                  : _buildProductivityByTimeChart(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildRecommendationsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.cyan.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.cyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'RECOMMENDATIONS',
                  style: TextStyle(
                    color: Colors.cyan,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _generateRecommendations(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 900.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildDistractionsTab() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDistractionSummary(),
            const SizedBox(height: 24),
            _buildDistractionTypesSection(),
            const SizedBox(height: 24),
            _buildDistractionTimeSection(),
            const SizedBox(height: 24),
            _buildDistractionSuggestionsSection(),
            const SizedBox(height: 80), // Bottom padding for scrolling
          ],
        ),
      ),
    );
  }
  
  Widget _buildDistractionSummary() {
    // Calculate distraction stats
    final totalDistractions = widget.distractionEntries.length;
    final totalSeconds = widget.distractionEntries.isEmpty ? 0 : 
      widget.distractionEntries.fold(0, (sum, entry) => sum + entry.durationSeconds);
    final avgSeconds = totalDistractions > 0 ? totalSeconds ~/ totalDistractions : 0;

    // Group distractions by hour
    final distractionHourMap = <int, int>{};
    for (var distraction in widget.distractionEntries) {
      final hour = distraction.timestamp.hour;
      distractionHourMap[hour] = (distractionHourMap[hour] ?? 0) + 1;
    }

    // Find most distracting hour
    int? mostDistractingHour;
    int maxDistractions = 0;
    distractionHourMap.forEach((hour, count) {
      if (count > maxDistractions) {
        maxDistractions = count;
        mostDistractingHour = hour;
      }
    });
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.redAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'DISTRACTION ANALYSIS',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHexagonalStat(
                      'Total',
                      totalDistractions.toString(),
                      Icons.warning_amber,
                      Colors.redAccent,
                    ),
                    _buildHexagonalStat(
                      'Avg Duration',
                      '$avgSeconds sec',
                      Icons.timer,
                      Colors.orangeAccent,
                    ),
                    _buildHexagonalStat(
                      'Total Lost',
                      '${(totalSeconds / 60).toStringAsFixed(1)} min',
                      Icons.hourglass_empty,
                      Colors.deepOrangeAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (mostDistractingHour != null)
  _buildInfoRow(
    'Most distracting hour',
    '${mostDistractingHour! > 12 ? mostDistractingHour! - 12 : mostDistractingHour!}${mostDistractingHour! >= 12 ? 'PM' : 'AM'}',
    '$maxDistractions distractions',
    Icons.access_time,
  )

              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildDistractionTypesSection() {
    // Group distractions by type
    final distractionTypeMap = <String, int>{};
    for (var distraction in widget.distractionEntries) {
      distractionTypeMap[distraction.type] = (distractionTypeMap[distraction.type] ?? 0) + 1;
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.redAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pie_chart,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'DISTRACTION TYPES',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 220,
              child: distractionTypeMap.isEmpty
                  ? _buildEmptyState('No distraction data available yet')
                  : _buildDistractionTypesChart(distractionTypeMap),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildDistractionTimeSection() {
    // Group distractions by hour
    final distractionHourMap = <int, int>{};
    for (var distraction in widget.distractionEntries) {
      final hour = distraction.timestamp.hour;
      distractionHourMap[hour] = (distractionHourMap[hour] ?? 0) + 1;
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.redAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'DISTRACTIONS BY TIME OF DAY',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 220,
              child: distractionHourMap.isEmpty
                  ? _buildEmptyState('No distraction time data available yet')
                  : _buildDistractionTimeChart(distractionHourMap),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildDistractionSuggestionsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.redAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'HOW TO REDUCE DISTRACTIONS',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _getDistractionSuggestions(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 900.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildMoodTab() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMoodSummary(),
            const SizedBox(height: 24),
            _buildMoodOverTimeSection(),
            const SizedBox(height: 24),
            _buildMoodVsProductivitySection(),
            const SizedBox(height: 24),
            _buildMoodSuggestionsSection(),
            const SizedBox(height: 80), // Bottom padding for scrolling
          ],
        ),
      ),
    );
  }
  
  Widget _buildMoodSummary() {
    // Calculate mood stats
    double avgMood = 3.0;
    if (widget.moodEntries.isNotEmpty) {
      avgMood = widget.moodEntries
          .map((entry) => entry.rating)
          .reduce((a, b) => a + b) / widget.moodEntries.length;
    }

    // Analyze correlation between mood and productivity
    double correlationScore = 0;
    if (widget.productivityEntries.isNotEmpty && widget.moodEntries.isNotEmpty) {
      // Simple correlation analysis
      final moodsByDay = <DateTime, List<MoodEntry>>{};
      for (var entry in widget.moodEntries) {
        final date = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
        if (moodsByDay[date] == null) {
          moodsByDay[date] = [];
        }
        moodsByDay[date]!.add(entry);
      }
      
      final matchingDays = <DateTime>[];
      final moodScores = <double>[];
      final productivityScores = <double>[];

      for (var prodEntry in widget.productivityEntries) {
        if (moodsByDay.containsKey(prodEntry.date)) {
          matchingDays.add(prodEntry.date);
          moodScores.add(moodsByDay[prodEntry.date]!
              .map((e) => e.rating)
              .reduce((a, b) => a + b) / moodsByDay[prodEntry.date]!.length);
          productivityScores.add(prodEntry.focusMinutes.toDouble());
        }
      }

      if (matchingDays.isNotEmpty) {
        // Simple correlation measure
        double moodSum = 0, prodSum = 0, moodProdSum = 0;
        double moodSqSum = 0, prodSqSum = 0;

        for (int i = 0; i < matchingDays.length; i++) {
          moodSum += moodScores[i];
          prodSum += productivityScores[i];
          moodProdSum += moodScores[i] * productivityScores[i];
          moodSqSum += moodScores[i] * moodScores[i];
          prodSqSum += productivityScores[i] * productivityScores[i];
        }

        final n = matchingDays.length.toDouble();
        final numerator = n * moodProdSum - moodSum * prodSum;
        final denominator = sqrt((n * moodSqSum - moodSum * moodSum) * (n * prodSqSum - prodSum * prodSum));

        if (denominator != 0) {
          correlationScore = numerator / denominator;
        }
      }
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.amber.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mood,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'MOOD ANALYSIS',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHexagonalStat(
                      'Average Mood',
                      avgMood.toStringAsFixed(1),
                      Icons.emoji_emotions,
                      Colors.amber,
                    ),
                    _buildHexagonalStat(
                      'Entries',
                      widget.moodEntries.length.toString(),
                      Icons.psychology,
                      Colors.teal,
                    ),
                    _buildHexagonalStat(
                      'Mood-Work Correlation',
                      correlationScore.toStringAsFixed(2),
                      Icons.sync_alt,
                      _getCorrelationColor(correlationScore),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildMoodOverTimeSection() {
    // Group mood entries by day
    final moodsByDay = <DateTime, List<MoodEntry>>{};
    for (var entry in widget.moodEntries) {
      final date = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
      if (moodsByDay[date] == null) {
        moodsByDay[date] = [];
      }
      moodsByDay[date]!.add(entry);
    }

    // Calculate daily average moods for the chart
    final dailyMoods = <MapEntry<DateTime, double>>[];
    moodsByDay.forEach((date, entries) {
      final avgDailyMood = entries
          .map((e) => e.rating)
          .reduce((a, b) => a + b) / entries.length;
      dailyMoods.add(MapEntry(date, avgDailyMood));
    });
    dailyMoods.sort((a, b) => a.key.compareTo(b.key));
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.amber.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.timeline,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'MOOD OVER TIME',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 220,
              child: dailyMoods.isEmpty
                  ? _buildEmptyState('No mood data available yet')
                  : _buildMoodOverTimeChart(dailyMoods),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildMoodVsProductivitySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.amber.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sync_alt,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'MOOD VS. PRODUCTIVITY',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 220,
              child: widget.productivityEntries.isEmpty || widget.moodEntries.isEmpty
                  ? _buildEmptyState('Not enough data to analyze mood vs. productivity')
                  : _buildMoodVsProductivityChart(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildMoodSuggestionsSection() {
    // Calculate correlation for suggestions
    double correlationScore = 0;
    if (widget.productivityEntries.isNotEmpty && widget.moodEntries.isNotEmpty) {
      // Simple correlation analysis
      final moodsByDay = <DateTime, List<MoodEntry>>{};
      for (var entry in widget.moodEntries) {
        final date = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
        if (moodsByDay[date] == null) {
          moodsByDay[date] = [];
        }
        moodsByDay[date]!.add(entry);
      }
      
      final matchingDays = <DateTime>[];
      final moodScores = <double>[];
      final productivityScores = <double>[];

      for (var prodEntry in widget.productivityEntries) {
        if (moodsByDay.containsKey(prodEntry.date)) {
          matchingDays.add(prodEntry.date);
          moodScores.add(moodsByDay[prodEntry.date]!
              .map((e) => e.rating)
              .reduce((a, b) => a + b) / moodsByDay[prodEntry.date]!.length);
          productivityScores.add(prodEntry.focusMinutes.toDouble());
        }
      }

      if (matchingDays.isNotEmpty) {
        // Simple correlation measure
        double moodSum = 0, prodSum = 0, moodProdSum = 0;
        double moodSqSum = 0, prodSqSum = 0;

        for (int i = 0; i < matchingDays.length; i++) {
          moodSum += moodScores[i];
          prodSum += productivityScores[i];
          moodProdSum += moodScores[i] * productivityScores[i];
          moodSqSum += moodScores[i] * moodScores[i];
          prodSqSum += productivityScores[i] * productivityScores[i];
        }

        final n = matchingDays.length.toDouble();
        final numerator = n * moodProdSum - moodSum * prodSum;
        final denominator = sqrt((n * moodSqSum - moodSum * moodSum) * (n * prodSqSum - prodSum * prodSum));

        if (denominator != 0) {
          correlationScore = numerator / denominator;
        }
      }
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.amber.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'MOOD PATTERNS & SUGGESTIONS',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _getMoodSuggestions(correlationScore),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 900.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildAiInsightsTab() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAiInsightsCard(),
            const SizedBox(height: 24),
            _buildAiVisualization(),
            const SizedBox(height: 80), // Bottom padding for scrolling
          ],
        ),
      ),
    );
  }
  
  Widget _buildAiInsightsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.purpleAccent.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: Colors.purpleAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.purpleAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'AI-POWERED INSIGHTS',
                  style: TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: _aiInsights == 'Loading AI insights...'
                ? Center(
                    child: Column(
                      children: [
                        Lottie.network(
                          'https://assets9.lottiefiles.com/packages/lf20_b88nh30c.json',
                          width: 100,
                          height: 100,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Analyzing your productivity data...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                : MarkdownBody(
                    data: _aiInsights,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70, fontSize: 14),
                      h1: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                      h2: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                      strong: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                      em: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey),
                      listBullet: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.cyan),
                    ),
                  ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildAiVisualization() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.purpleAccent.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border.all(
                color: Colors.purpleAccent.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_graph,
                    color: Colors.purpleAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'PRODUCTIVITY NEURAL NETWORK',
                  style: TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: CustomPaint(
                    size: const Size(double.infinity, 200),
                    painter: NeuralNetworkPainter(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'AI is analyzing patterns in your productivity data to provide personalized insights and recommendations.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.1, end: 0);
  }
  
  // Utility functions for charts and visualizations
  Widget _buildFocusMinutesChart(List<ProductivityEntry> entries) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: entries.isEmpty ? 10 : (entries.map((e) => e.focusMinutes).reduce((a, b) => a > b ? a : b) * 1.2).toDouble(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= entries.length || value.toInt() < 0) return const SizedBox();
                return Text(
                  DateFormat('E').format(entries[value.toInt()].date),
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 30,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.cyan.withOpacity(0.1),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          entries.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: entries[index].focusMinutes.toDouble(),
                gradient: LinearGradient(
                  colors: [Colors.cyan, Colors.blue.shade900],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                width: 15,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: entries.isEmpty ? 10 : (entries.map((e) => e.focusMinutes).reduce((a, b) => a > b ? a : b) * 1.2).toDouble(),
                  color: Colors.cyan.withOpacity(0.05),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProductivityByTimeChart() {
    // Group focus minutes by hour of day
    final hourlyFocusMap = <int, int>{};
    for (final session in widget.focusSessions) {
      final hour = session.startTime.hour;
      hourlyFocusMap[hour] = (hourlyFocusMap[hour] ?? 0) + (session.actualDurationMinutes ?? 0);
    }
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          horizontalInterval: 30,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.green.withOpacity(0.1),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
          drawVerticalLine: false,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= 24) return const SizedBox();
                final hour = value.toInt();
                if (hour % 3 == 0) {
                  return Text(
                    '${hour > 12 ? hour - 12 : hour}${hour >= 12 ? 'PM' : 'AM'}',
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(24, (index) {
              return FlSpot(index.toDouble(), (hourlyFocusMap[index] ?? 0).toDouble());
            }),
            isCurved: true,
            gradient: const LinearGradient(
              colors: [Colors.greenAccent, Colors.green],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: Colors.greenAccent,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.3),
                  Colors.green.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        minY: 0,
      ),
    );
  }
  
  Widget _buildDistractionTypesChart(Map<String, int> distractionTypeMap) {
    final totalDistractions = distractionTypeMap.values.fold(0, (sum, count) => sum + count);
    final List<PieChartSectionData> sections = [];
    
    final colors = [
      Colors.redAccent,
      Colors.orangeAccent,
      Colors.amberAccent,
      Colors.pinkAccent,
      Colors.purpleAccent
    ];
    int colorIndex = 0;
    
    distractionTypeMap.forEach((type, count) {
      final percentage = count / totalDistractions * 100;
      sections.add(
        PieChartSectionData(
          color: colors[colorIndex % colors.length],
          value: percentage,
          title: '$type\n${percentage.toStringAsFixed(1)}%',
          radius: 80,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          badgeWidget: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: colors[colorIndex % colors.length],
                width: 1,
              ),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: colors[colorIndex % colors.length],
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          badgePositionPercentageOffset: 0.9,
        ),
      );
      colorIndex++;
    });
    
    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
        centerSpaceColor: Colors.black.withOpacity(0.5),
      ),
    );
  }
  
  Widget _buildDistractionTimeChart(Map<int, int> distractionHourMap) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: distractionHourMap.isEmpty ? 1 : 
          (distractionHourMap.values.fold(0, (max, count) => count > max ? count : max) * 1.2).toDouble(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= 24) return const SizedBox();
                final hour = value.toInt();
                if (hour % 3 == 0) {
                  return Text(
                    '${hour > 12 ? hour - 12 : hour}${hour >= 12 ? 'PM' : 'AM'}',
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.redAccent.withOpacity(0.1),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          24,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (distractionHourMap[index] ?? 0).toDouble(),
                gradient: LinearGradient(
                  colors: [Colors.redAccent, Colors.red.shade900],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                width: 10,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: distractionHourMap.isEmpty ? 1 : 
                    (distractionHourMap.values.fold(0, (max, count) => count > max ? count : max) * 1.2).toDouble(),
                  color: Colors.redAccent.withOpacity(0.05),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMoodOverTimeChart(List<MapEntry<DateTime, double>> dailyMoods) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.amber.withOpacity(0.1),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
          drawVerticalLine: false,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= dailyMoods.length) return const SizedBox();
                return Text(
                  DateFormat('M/d').format(dailyMoods[value.toInt()].key),
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(dailyMoods.length, (index) {
              return FlSpot(index.toDouble(), dailyMoods[index].value);
            }),
            isCurved: true,
            gradient: const LinearGradient(
              colors: [Colors.amber, Colors.orange],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: Colors.amber,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withOpacity(0.3),
                  Colors.amber.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        minY: 1,
        maxY: 5,
      ),
    );
  }
  
  Widget _buildMoodVsProductivityChart() {
    final points = <FlSpot>[];
    final matchingData = <MapEntry<double, double>>[];
    
    for (var prodEntry in widget.productivityEntries) {
      final moodEntries = widget.moodEntries.where((mood) => 
        mood.timestamp.year == prodEntry.date.year &&
        mood.timestamp.month == prodEntry.date.month &&
        mood.timestamp.day == prodEntry.date.day
      ).toList();
      
      if (moodEntries.isNotEmpty) {
        final avgMood = moodEntries
            .map((e) => e.rating)
            .reduce((a, b) => a + b) / moodEntries.length;
        
        matchingData.add(MapEntry(avgMood, prodEntry.focusMinutes.toDouble()));
      }
    }
    
    // Sort by mood for better visualization
    matchingData.sort((a, b) => a.key.compareTo(b.key));
    
    for (int i = 0; i < matchingData.length; i++) {
      points.add(FlSpot(i.toDouble(), matchingData[i].value));
    }
    
    return points.isEmpty
        ? _buildEmptyState('Not enough data yet')
        : LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                horizontalInterval: 30,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.purpleAccent.withOpacity(0.1),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  );
                },
                drawVerticalLine: false,
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(color: Colors.white60, fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() < 0 || value.toInt() >= matchingData.length) return const SizedBox();
                      return Text(
                        matchingData[value.toInt()].key.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white60, fontSize: 10),
                      );
                    },
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (_, __) => const Text(
                      'Mood (x-axis) vs. Focus Minutes (y-axis)',
                      style: TextStyle(color: Colors.white60, fontSize: 10),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: points,
                  isCurved: false,
                  gradient: const LinearGradient(
                    colors: [Colors.purpleAccent, Colors.deepPurple],
                  ),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Colors.purpleAccent,
                        strokeWidth: 1,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                ),
              ],
              minY: 0,
            ),
          );
  }
  
  Widget _buildHexagonalStat(String label, String value, IconData icon, Color color) {
    return Container(
      width: 100,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hexagon background
          CustomPaint(
            size: const Size(80, 80),
            painter: HexagonPainter(color: color.withOpacity(0.1)),
          ),
          
          // Content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, String subvalue, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.cyan,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.cyan.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              subvalue,
              style: const TextStyle(
                color: Colors.cyan,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.network(
            'https://assets9.lottiefiles.com/packages/lf20_ydo1amjm.json',
            width: 100,
            height: 100,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  List<Widget> _generateRecommendations() {
    final recommendations = <Widget>[];
    
    // Find optimal work times
    if (widget.focusSessions.isNotEmpty) {
      final hourlyProductivityMap = <int, int>{};
      for (var session in widget.focusSessions) {
       final hour = session.startTime.hour;
        hourlyProductivityMap[hour] = (hourlyProductivityMap[hour] ?? 0) + 
          (session.actualDurationMinutes ?? 0);
      }
      
      // Find top 3 productive hours
      final sortedHours = hourlyProductivityMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      if (sortedHours.isNotEmpty) {
        recommendations.add(
          _buildRecommendationHeader('Optimal Focus Times', Icons.schedule),
        );
        
        int count = 0;
        for (var entry in sortedHours) {
          if (count >= 3) break;
          
          final hour = entry.key;
          final timeString = '${hour > 12 ? hour - 12 : hour}${hour >= 12 ? 'PM' : 'AM'}';
          recommendations.add(
            _buildRecommendationItem('$timeString - ${entry.value} minutes of focus'),
          );
          count++;
        }
      }
    }
    
    // Add task strategy recommendations
    recommendations.add(
      _buildRecommendationHeader('Weekly Productivity Insights', Icons.lightbulb_outline),
    );
    
    // Dynamic suggestions based on data
    if (widget.productivityEntries.isNotEmpty) {
      final avgTasksPerDay = widget.productivityEntries
.map((e) => e?.tasksCompleted ?? 0)
          .reduce((a, b) => a + b) / widget.productivityEntries.length;
      
      if (avgTasksPerDay < 3) {
        recommendations.add(
          _buildRecommendationItem('Try breaking down larger tasks into smaller, manageable ones'),
        );
      } else {
        recommendations.add(
          _buildRecommendationItem('Good job completing tasks consistently! Consider increasing task difficulty'),
        );
      }
    }
    
    // Add more general recommendations
    recommendations.add(
      _buildRecommendationItem('Schedule focus sessions during your peak productivity hours'),
    );
    
    recommendations.add(
      _buildRecommendationItem('Take short breaks between focus sessions to maintain energy'),
    );
    
    return recommendations;
  }
  
  Widget _buildRecommendationHeader(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.cyan,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecommendationItem(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 36),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.cyan,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  List<Widget> _getDistractionSuggestions() {
    final suggestions = <Widget>[];
    
    // Find most common distraction type
    String? mostCommonType;
    int maxCount = 0;
    final typeMap = <String, int>{};
    
    for (var distraction in widget.distractionEntries) {
      typeMap[distraction.type] = (typeMap[distraction.type] ?? 0) + 1;
      if ((typeMap[distraction.type] ?? 0) > maxCount) {
        maxCount = typeMap[distraction.type]!;
        mostCommonType = distraction.type;
      }
    }
    
    // Add personalized suggestions based on distraction patterns
    if (mostCommonType != null) {
      suggestions.add(
        _buildRecommendationHeader('Reduce "$mostCommonType" Distractions', Icons.trending_down),
      );
      
      // Custom suggestions based on type
      if (mostCommonType.toLowerCase().contains('phone') || 
          mostCommonType.toLowerCase().contains('notification')) {
        suggestions.add(
          _buildRecommendationItem('Enable "Do Not Disturb" mode during focus sessions'),
        );
        suggestions.add(
          _buildRecommendationItem('Keep your phone in another room or in a drawer'),
        );
      } else if (mostCommonType.toLowerCase().contains('social') || 
                 mostCommonType.toLowerCase().contains('web')) {
        suggestions.add(
          _buildRecommendationItem('Use website blockers during focus sessions'),
        );
        suggestions.add(
          _buildRecommendationItem('Schedule specific times to check social media'),
        );
      } else if (mostCommonType.toLowerCase().contains('noise') || 
                 mostCommonType.toLowerCase().contains('people')) {
        suggestions.add(
          _buildRecommendationItem('Use noise-cancelling headphones or ambient sounds'),
        );
        suggestions.add(
          _buildRecommendationItem('Find a quieter workspace or set boundaries with others'),
        );
      }
    }
    
    // Add distraction pattern analysis
    suggestions.add(
      _buildRecommendationHeader('Distraction Patterns', Icons.insights),
    );
    
    // Analyze time pattern of distractions
    if (widget.distractionEntries.isNotEmpty) {
      // Group by hour
      final hourlyDistractions = <int, int>{};
      for (var entry in widget.distractionEntries) {
        final hour = entry.timestamp.hour;
        hourlyDistractions[hour] = (hourlyDistractions[hour] ?? 0) + 1;
      }
      
      // Find peak distraction hours (top 2)
      final sortedHours = hourlyDistractions.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      if (sortedHours.isNotEmpty) {
        suggestions.add(
          _buildRecommendationItem('Your peak distraction hours: ${_formatHourRanges(sortedHours.take(2).map((e) => e.key).toList())}'),
        );
        suggestions.add(
          _buildRecommendationItem('Plan deep focus work outside these high-distraction periods'),
        );
      }
    }
    
    // General suggestions
    suggestions.add(
      _buildRecommendationHeader('General Strategies', Icons.lightbulb_outline),
    );
    
    suggestions.add(
      _buildRecommendationItem('Use the Pomodoro Technique: 25 minutes of focus followed by a 5-minute break'),
    );
    
    suggestions.add(
      _buildRecommendationItem('Create a dedicated workspace with minimal distractions'),
    );
    
    suggestions.add(
      _buildRecommendationItem('Set clear goals for each focus session before starting'),
    );
    
    return suggestions;
  }
  
  String _formatHourRanges(List<int> hours) {
    if (hours.isEmpty) return '';
    
    final formattedHours = hours.map((hour) => 
      '${hour > 12 ? hour - 12 : hour}${hour >= 12 ? 'PM' : 'AM'}'
    ).toList();
    
    return formattedHours.join(', ');
  }
  
  List<Widget> _getMoodSuggestions(double correlationScore) {
    final suggestions = <Widget>[];
    
    // Add correlation analysis
    suggestions.add(
      _buildRecommendationHeader('Mood-Productivity Connection', Icons.psychology),
    );
    
    if (correlationScore.abs() < 0.2) {
      suggestions.add(
        _buildRecommendationItem('Your mood and productivity don\'t seem strongly connected'),
      );
      suggestions.add(
        _buildRecommendationItem('Consider tracking other factors that might affect your productivity'),
      );
    } else if (correlationScore > 0.2) {
      suggestions.add(
        _buildRecommendationItem('Higher mood appears to boost your productivity'),
      );
      suggestions.add(
        _buildRecommendationItem('Focus on activities that improve your mood before work sessions'),
      );
    } else if (correlationScore < -0.2) {
      suggestions.add(
        _buildRecommendationItem('Interestingly, you seem more productive when in a lower mood'),
      );
      suggestions.add(
        _buildRecommendationItem('Consider channeling emotional energy into focused work'),
      );
    }
    
    // Add mood improvement suggestions
    suggestions.add(
      _buildRecommendationHeader('Mood Enhancement', Icons.sentiment_satisfied_alt),
    );
    
    suggestions.add(
      _buildRecommendationItem('Take short breaks for physical activity to boost mood and energy'),
    );
    
    suggestions.add(
      _buildRecommendationItem('Practice mindfulness or brief meditation between focus sessions'),
    );
    
    suggestions.add(
      _buildRecommendationItem('Celebrate small wins and progress to maintain positive momentum'),
    );
    
    // Add work-life balance suggestions
    suggestions.add(
      _buildRecommendationHeader('Work-Life Balance', Icons.balance),
    );
    
    suggestions.add(
      _buildRecommendationItem('Set clear boundaries between work and personal time'),
    );
    
    suggestions.add(
      _buildRecommendationItem('Schedule regular activities you enjoy to maintain overall wellbeing'),
    );
    
    return suggestions;
  }
  
  Color _getCorrelationColor(double score) {
    if (score.abs() < 0.2) {
      return Colors.grey;
    } else if (score > 0.2) {
      return Colors.greenAccent;
    } else {
      return Colors.orangeAccent;
    }
  }
}