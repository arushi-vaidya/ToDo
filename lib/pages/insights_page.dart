import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import '../models/task.dart';
import '../models/mood_entry.dart';
import '../models/distraction_entry.dart';
import '../models/focus_session.dart';
import '../models/productivity_entry.dart';


import 'package:fl_chart/fl_chart.dart';

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
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyan,
          tabs: const [
            Tab(text: 'Productivity'),
            Tab(text: 'Distractions'),
            Tab(text: 'Mood'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductivityTab(),
          _buildDistractionsTab(),
          _buildMoodTab(),
        ],
      ),
    );
  }
  
  Widget _buildProductivityTab() {
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
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weekly summary
          Card(
            color: Colors.black,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Productivity Recap',
                    style: TextStyle(
                      color: Colors.cyan,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCard(
                        'Focus Minutes',
                        weeklyFocusMinutes.toString(),
                        Icons.timer,
                        Colors.green,
                      ),
                      _buildStatCard(
                        'Tasks Completed',
                        weeklyTasksCompleted.toString(),
                        Icons.task_alt,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Focus Sessions',
                        widget.focusSessions.length.toString(),
                        Icons.psychology,
                        Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (mostProductiveDay != null)
                    Text(
                      'Most productive day: ${DateFormat('EEEE').format(mostProductiveDay.date)} (${mostProductiveDay.focusMinutes} min)',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  if (mostProductiveHour != null)
                    Text(
                      'Most productive hour: ${mostProductiveHour! > 12 ? mostProductiveHour! - 12 : mostProductiveHour!}${mostProductiveHour! >= 12 ? 'PM' : 'AM'} ($maxMinutes min)',
                      style: const TextStyle(color: Colors.white70),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Daily Focus Minutes Chart
          const Text(
            'Daily Focus Minutes',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: widget.productivityEntries.isEmpty
                ? const Center(child: Text('No data available yet', style: TextStyle(color: Colors.grey)))
                : _buildFocusMinutesChart(),
          ),
          
          const SizedBox(height: 24),
          
          // Productivity by Time of Day
          const Text(
            'Productivity by Time of Day',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: widget.focusSessions.isEmpty
                ? const Center(child: Text('No data available yet', style: TextStyle(color: Colors.grey)))
                : _buildProductivityByTimeChart(),
          ),
          
          const SizedBox(height: 24),
          
          // Weekly Recommendations
          Card(
            color: Colors.black,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Recommendations',
                    style: TextStyle(
                      color: Colors.cyan,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._generateRecommendations(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDistractionsTab() {
    // Calculate distraction stats
    final totalDistractions = widget.distractionEntries.length;
    final totalSeconds = widget.distractionEntries.fold(0, (sum, entry) => sum + entry.durationSeconds);
    final avgSeconds = totalDistractions > 0 ? totalSeconds ~/ totalDistractions : 0;
    
    // Group distractions by type
    final distractionTypeMap = <String, int>{};
    for (var distraction in widget.distractionEntries) {
      distractionTypeMap[distraction.type] = (distractionTypeMap[distraction.type] ?? 0) + 1;
    }
    
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
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Distraction summary
          Card(
            color: Colors.black,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Distraction Analysis',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCard(
                        'Total',
                        totalDistractions.toString(),
                        Icons.warning_amber,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        'Avg Duration',
                        '$avgSeconds sec',
                        Icons.timer,
                        Colors.redAccent,
                      ),
                      _buildStatCard(
                        'Total Lost',
                        '${(totalSeconds / 60).toStringAsFixed(1)} min',
                        Icons.hourglass_empty,
                        Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (mostDistractingHour != null)
                    Text(
                      'Most distracting hour: ${mostDistractingHour! > 12 ? mostDistractingHour! - 12 : mostDistractingHour!}${mostDistractingHour! >= 12 ? 'PM' : 'AM'} ($maxDistractions distractions)',
                      style: const TextStyle(color: Colors.white70),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Distraction Types Chart
          const Text(
            'Distraction Types',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: distractionTypeMap.isEmpty
                ? const Center(child: Text('No data available yet', style: TextStyle(color: Colors.grey)))
                : _buildDistractionTypesChart(distractionTypeMap),
          ),
          
          const SizedBox(height: 24),
          
          // Distraction Time Chart
          const Text(
            'Distractions by Time of Day',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: distractionHourMap.isEmpty
                ? const Center(child: Text('No data available yet', style: TextStyle(color: Colors.grey)))
                : _buildDistractionTimeChart(distractionHourMap),
          ),
          
          const SizedBox(height: 24),
          
          // Improvement Suggestions
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How to Reduce Distractions',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._getDistractionSuggestions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMoodTab() {
    // Calculate mood stats
    double avgMood = 3.0;
    if (widget.moodEntries.isNotEmpty) {
      avgMood = widget.moodEntries
        .map((entry) => entry.rating)
        .reduce((a, b) => a + b) / widget.moodEntries.length;
    }
    
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
    
    // Analyze correlation between mood and productivity
    double correlationScore = 0;
    if (widget.productivityEntries.isNotEmpty && moodsByDay.isNotEmpty) {
      // Simple correlation analysis (could be more sophisticated in a real app)
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
        // Simple correlation measure (just for demonstration)
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
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mood summary
          Card(
            color: Colors.black,
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mood Analysis',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCard(
                        'Average Mood',
                        avgMood.toStringAsFixed(1),
                        Icons.emoji_emotions,
                        Colors.amber,
                      ),
                      _buildStatCard(
                        'Entries',
                        widget.moodEntries.length.toString(),
                        Icons.psychology,
                        Colors.teal,
                      ),
                      _buildStatCard(
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
          ),
          
          const SizedBox(height: 24),
          
          // Mood Over Time Chart
          const Text(
            'Mood Over Time',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: dailyMoods.isEmpty
                ? const Center(child: Text('No data available yet', style: TextStyle(color: Colors.grey)))
                : _buildMoodOverTimeChart(dailyMoods),
          ),
          
          const SizedBox(height: 24),
          
          // Mood vs Productivity
          const Text(
            'Mood vs. Productivity',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: widget.productivityEntries.isEmpty || moodsByDay.isEmpty
                ? const Center(child: Text('No data available yet', style: TextStyle(color: Colors.grey)))
                : _buildMoodVsProductivityChart(),
          ),
                    
          const SizedBox(height: 24),
          
          // Mood Patterns
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mood Patterns & Suggestions',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._getMoodSuggestions(correlationScore),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Utility functions for charts and visualizations
  Widget _buildFocusMinutesChart() {
    final entries = widget.productivityEntries.toList();
    entries.sort((a, b) => a.date.compareTo(b.date));
    final last7Entries = entries.length > 7 ? entries.sublist(entries.length - 7) : entries;
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (last7Entries.map((e) => e.focusMinutes).reduce((a, b) => a > b ? a : b) * 1.2).toDouble(),
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
                if (value.toInt() >= last7Entries.length || value.toInt() < 0) return const SizedBox();
                return Text(
                  DateFormat('E').format(last7Entries[value.toInt()].date),
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          last7Entries.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: last7Entries[index].focusMinutes.toDouble(),
                color: Colors.cyan,
                width: 15,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
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
    
    final sortedHours = hourlyFocusMap.keys.toList()..sort();
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
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
                return Text(
                  '${hour > 12 ? hour - 12 : hour}${hour >= 12 ? 'PM' : 'AM'}',
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
            spots: List.generate(24, (index) {
              return FlSpot(index.toDouble(), (hourlyFocusMap[index] ?? 0).toDouble());
            }),
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withOpacity(0.3),
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
    
    final colors = [Colors.red, Colors.orange, Colors.yellow, Colors.pink, Colors.purple];
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
        ),
      );
      colorIndex++;
    });
    
    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }
  
  Widget _buildDistractionTimeChart(Map<int, int> distractionHourMap) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (distractionHourMap.values.fold(0, (max, count) => count > max ? count : max) * 1.2).toDouble(),
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
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          24,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (distractionHourMap[index] ?? 0).toDouble(),
                color: Colors.redAccent,
                width: 10,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
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
        gridData: FlGridData(show: false),
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
            color: Colors.amber,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.amber.withOpacity(0.3),
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
        ? const Center(child: Text('Not enough data yet', style: TextStyle(color: Colors.grey)))
        : LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
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
                  color: Colors.purpleAccent,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                ),
              ],
              minY: 0,
            ),
          );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
          const ListTile(
            leading: Icon(Icons.schedule, color: Colors.cyan),
            title: Text('Optimal Focus Times',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            contentPadding: EdgeInsets.zero,
          ),
        );
        
        int count = 0;
        for (var entry in sortedHours) {
          if (count >= 3) break;
          
          final hour = entry.key;
          final timeString = '${hour > 12 ? hour - 12 : hour}${hour >= 12 ? 'PM' : 'AM'}';
          recommendations.add(
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
              child: Text(
                '• $timeString - ${entry.value} minutes of focus',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
          count++;
        }
      }
    }
    
    // Add task strategy recommendations
    recommendations.add(
      const ListTile(
        leading: Icon(Icons.lightbulb_outline, color: Colors.amber),
        title: Text('Weekly Productivity Insights',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        contentPadding: EdgeInsets.zero,
      ),
    );
    
    // Dynamic suggestions based on data
    if (widget.productivityEntries.isNotEmpty) {
      final avgTasksPerDay = widget.productivityEntries
          .map((e) => e.tasksCompleted)
          .reduce((a, b) => a + b) / widget.productivityEntries.length;
      
      if (avgTasksPerDay < 3) {
        recommendations.add(
          const Padding(
            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              '• Try breaking down larger tasks into smaller, manageable ones',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
      } else {
        recommendations.add(
          const Padding(
            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              '• Good job completing tasks consistently! Consider increasing task difficulty',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
      }
    }
    
    // Add more general recommendations
    recommendations.add(
      const Padding(
        padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
        child: Text(
          '• Schedule focus sessions during your peak productivity hours',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
    
    recommendations.add(
      const Padding(
        padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
        child: Text(
          '• Take short breaks between focus sessions to maintain energy',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
    
    return recommendations;
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
        ListTile(
          leading: const Icon(Icons.trending_down, color: Colors.red),
          title: Text('Reduce "$mostCommonType" Distractions',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          contentPadding: EdgeInsets.zero,
        ),
      );
      
      // Custom suggestions based on type
      if (mostCommonType.toLowerCase().contains('phone') || 
          mostCommonType.toLowerCase().contains('notification')) {
        suggestions.add(
          const Padding(
            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              '• Enable "Do Not Disturb" mode during focus sessions',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
        suggestions.add(
          const Padding(
            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              '• Keep your phone in another room or in a drawer',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
      } else if (mostCommonType.toLowerCase().contains('social') || 
                 mostCommonType.toLowerCase().contains('web')) {
        suggestions.add(
          const Padding(
            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              '• Use website blockers during focus sessions',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
        suggestions.add(
          const Padding(
            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              '• Schedule specific times to check social media',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
      } else if (mostCommonType.toLowerCase().contains('noise') || 
                 mostCommonType.toLowerCase().contains('people')) {
        suggestions.add(
          const Padding(
            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              '• Use noise-cancelling headphones or ambient sounds',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
        suggestions.add(
          const Padding(
            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              '• Find a quieter workspace or set boundaries with others',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
      }
    }
    
    // Add distraction pattern analysis
    suggestions.add(
      const ListTile(
        leading: Icon(Icons.insights, color: Colors.orange),
        title: Text('Distraction Patterns',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        contentPadding: EdgeInsets.zero,
      ),
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
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              '• Your peak distraction hours: ${_formatHourRanges(sortedHours.take(2).map((e) => e.key).toList())}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        );
        suggestions.add(
          const Padding(
            padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              '• Plan deep focus work outside these high-distraction periods',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
      }
      
      // Check for increasing trend
      if (widget.distractionEntries.length >= 3) {
        final recentDays = 3;
        final entriesByDay = <DateTime, List<DistractionEntry>>{};
        
        for (var entry in widget.distractionEntries) {
          final date = DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day);
          if (entriesByDay[date] == null) entriesByDay[date] = [];
          entriesByDay[date]!.add(entry);
        }
        
        final dates = entriesByDay.keys.toList()..sort((a, b) => a.compareTo(b));
        if (dates.length >= recentDays) {
          final recentDates = dates.sublist(dates.length - recentDays);
          final countsByDay = recentDates.map((date) => entriesByDay[date]!.length).toList();
          
          bool increasing = true;
          for (int i = 1; i < countsByDay.length; i++) {
            if (countsByDay[i] <= countsByDay[i-1]) {
              increasing = false;
              break;
            }
          }
          
          if (increasing) {
            suggestions.add(
              const Padding(
                padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
                child: Text(
                  '• Warning: Your distractions are trending upward - consider a digital detox',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            );
          }
        }
      }
    }
    
    // General suggestions
    suggestions.add(
      const ListTile(
        leading: Icon(Icons.tips_and_updates, color: Colors.green),
        title: Text('General Tips',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        contentPadding: EdgeInsets.zero,
      ),
    );
    
    suggestions.add(
      const Padding(
        padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
        child: Text(
          '• Use the Pomodoro technique (25 min focus, 5 min break)',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
    
    suggestions.add(
      const Padding(
        padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
        child: Text(
          '• Create a dedicated workspace with minimal distractions',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
    
    suggestions.add(
      const Padding(
        padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
        child: Text(
          '• Practice mindfulness to catch yourself before getting distracted',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
    
    return suggestions;
  }
  
  String _formatHourRanges(List<int> hours) {
    if (hours.isEmpty) return '';
    
    final formattedHours = hours.map((hour) {
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour$period';
    }).toList();
    
    return formattedHours.join(', ');
  }
  
  List<Widget> _getMoodSuggestions(double correlationScore) {
    final suggestions = <Widget>[];
    
    // Analyze mood-productivity correlation
    suggestions.add(
      ListTile(
        leading: Icon(Icons.psychology, color: _getCorrelationColor(correlationScore)),
        title: const Text('Mood & Productivity Connection',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        contentPadding: EdgeInsets.zero,
      ),
    );
    
    // Correlation interpretation
    if (correlationScore.abs() < 0.2) {
      suggestions.add(
        const Padding(
          padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Text(
            '• Your mood and productivity appear to have little correlation',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
      suggestions.add(
        const Padding(
          padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Text(
            '• You may be skilled at working regardless of emotional state',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    } else if (correlationScore >= 0.2) {
      suggestions.add(
        const Padding(
          padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Text(
            '• Higher mood tends to boost your productivity',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
      suggestions.add(
        const Padding(
          padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Text(
            '• Consider incorporating mood-lifting activities before focus sessions',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    } else if (correlationScore <= -0.2) {
      suggestions.add(
        const Padding(
          padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Text(
            '• Interestingly, you tend to be more productive when in a lower mood',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
      suggestions.add(
        const Padding(
          padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Text(
            '• You might use work as a coping mechanism or distraction',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    
    // Look for mood patterns
    if (widget.moodEntries.isNotEmpty && widget.moodEntries.length >= 5) {
      // Group by time of day
      final morningMoods = widget.moodEntries
          .where((e) => e.timestamp.hour >= 5 && e.timestamp.hour < 12)
          .map((e) => e.rating);
      final afternoonMoods = widget.moodEntries
          .where((e) => e.timestamp.hour >= 12 && e.timestamp.hour < 18)
          .map((e) => e.rating);
      final eveningMoods = widget.moodEntries
          .where((e) => e.timestamp.hour >= 18 || e.timestamp.hour < 5)
          .map((e) => e.rating);
      
      // Calculate averages if there's enough data
      if (morningMoods.isNotEmpty && afternoonMoods.isNotEmpty && eveningMoods.isNotEmpty) {
        final avgMorning = morningMoods.reduce((a, b) => a + b) / morningMoods.length;
        final avgAfternoon = afternoonMoods.reduce((a, b) => a + b) / afternoonMoods.length;
        final avgEvening = eveningMoods.reduce((a, b) => a + b) / eveningMoods.length;
        
        // Find peak mood time
        final moodTimes = [
          {'time': 'morning', 'avg': avgMorning},
          {'time': 'afternoon', 'avg': avgAfternoon},
          {'time': 'evening', 'avg': avgEvening}
        ];
        moodTimes.sort((a, b) => (b['avg']! as double).compareTo(a['avg']! as double));
        
        suggestions.add(
          ListTile(
            leading: const Icon(Icons.access_time, color: Colors.amber),
            title: const Text('Mood Patterns',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            contentPadding: EdgeInsets.zero,
          ),
        );
        
        suggestions.add(
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Text(
              '• Your mood is typically highest in the ${moodTimes[0]['time']}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        );
        
        if (correlationScore >= 0.2) {
          suggestions.add(
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
              child: Text(
                '• Schedule important tasks in the ${moodTimes[0]['time']} when your mood is best',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }
      }
    }
    
    // General mood-boosting suggestions
    suggestions.add(
      const ListTile(
        leading: Icon(Icons.self_improvement, color: Colors.lightBlue),
        title: Text('Mood-Boosting Activities',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        contentPadding: EdgeInsets.zero,
      ),
    );
    
    suggestions.add(
      const Padding(
        padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
        child: Text(
          '• Short mindfulness or meditation breaks',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
    
    suggestions.add(
      const Padding(
        padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
        child: Text(
          '• Physical activity: quick walks or stretching',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
    
    suggestions.add(
      const Padding(
        padding: EdgeInsets.only(left: 16.0, bottom: 8.0),
        child: Text(
          '• Gratitude journaling between focus sessions',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
    
    return suggestions;
  }
  
  Color _getCorrelationColor(double correlation) {
    final absCorrelation = correlation.abs();
    if (absCorrelation < 0.2) return Colors.grey;
    if (absCorrelation < 0.4) return Colors.blue;
    if (absCorrelation < 0.6) return Colors.green;
    if (absCorrelation < 0.8) return Colors.orange;
    return Colors.purple;
  }
}