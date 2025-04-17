import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart';
import '../models/task.dart';
import '../models/time_slot.dart';
import 'dart:math' show pi;

int getMinutesFromTimeString(String time) {
  final parts = time.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  return hour * 60 + minute;
}

class SmartTodoPage extends StatefulWidget {
  final List<Task> tasks;
  final List<Task> priorityTasks;
  final Function(Task) onTaskAdded;
  final Function(String, bool) onTaskCompleted;
  final Function(String) onTaskDeleted;

  const SmartTodoPage({
    Key? key,
    required this.tasks,
    required this.priorityTasks,
    required this.onTaskAdded,
    required this.onTaskCompleted,
    required this.onTaskDeleted,
  }) : super(key: key);

  @override
  State<SmartTodoPage> createState() => _SmartTodoPageState();
}

class _SmartTodoPageState extends State<SmartTodoPage> {
  String _filter = 'today';
  String _searchQuery = '';
  bool _isAddTaskOpen = false;
  bool _isAutoScheduleOpen = false;
  List<TimeSlot> _availableTimeSlots = [];
  bool _showConfetti = false;
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 2));

  List<TimeSlot> generateTimeSlots({
    required DateTime date,
    int startHour = 8,
    int endHour = 18,
    int intervalMinutes = 30,
  }) {
    List<TimeSlot> slots = [];

    for (int hour = startHour; hour < endHour; hour++) {
      for (int minute = 0; minute < 60; minute += intervalMinutes) {
        final startTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        final endMinute = minute + intervalMinutes;
        final endHourAdjusted = hour + (endMinute ~/ 60);
        final endMinuteAdjusted = endMinute % 60;

        final endTime = '${endHourAdjusted.toString().padLeft(2, '0')}:${endMinuteAdjusted.toString().padLeft(2, '0')}';

        int nextId = slots.length + 1; // Or some other logic to generate a unique ID
        slots.add(TimeSlot(
          id: nextId,
          date: date.toIso8601String(),
          startTime: startTime,
          endTime: endTime,
        ));
      }
    }

    return slots;
  }

  @override
  void initState() {
    super.initState();
    DateTime currentDate = DateTime.now();  // Gets the current date and time
    _availableTimeSlots = generateTimeSlots(date: currentDate);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _handleAddTask(Task task) {
    widget.onTaskAdded(task);
    setState(() {
      _isAddTaskOpen = false;
    });
  }

  void _handleTaskCompleted(String taskId, bool completed) {
    widget.onTaskCompleted(taskId, completed);
    if (completed) {
      setState(() {
        _showConfetti = true;
      });
      _confettiController.play();
    }
  }

  void _handleTaskDeleted(String taskId) {
    widget.onTaskDeleted(taskId);
  }

  void _autoScheduleAllTasks() {
    // Get all unscheduled tasks
    final allTasks = [...widget.tasks, ...widget.priorityTasks];
    final unscheduledTasks = allTasks
        .where((task) => task.deadline == null && !task.isCompleted)
        .toList()
      ..sort((a, b) {
        // Sort by priority (highest first)
        if (a.priority != b.priority) {
          return b.priority.compareTo(a.priority);
        }
        // Then by estimated duration (shortest first for same priority)
        return a.estimatedMinutes.compareTo(b.estimatedMinutes);
      });

    if (unscheduledTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unscheduled tasks to schedule!')),
      );
      return;
    }

    // Sort available slots by date and time
    final sortedSlots = [..._availableTimeSlots]..sort((a, b) {
        final dateA = DateTime.parse(a.date);
        final dateB = DateTime.parse(b.date);
        if (dateA != dateB) {
          return dateA.compareTo(dateB);
        }
        return a.startTime.compareTo(b.startTime);
      });

    // Track remaining minutes in each slot
    final slotRemainingMinutes = <String, int>{};
    for (final slot in sortedSlots) {
      slotRemainingMinutes[slot.id.toString()] = slot.getRemainingMinutes();
    }

    // Schedule each task
    final updatedTasks = [...widget.tasks];
    final updatedPriorityTasks = [...widget.priorityTasks];
    int scheduledCount = 0;

    for (final task in unscheduledTasks) {
      TimeSlot? bestSlot;
      double bestScore = -1;

      for (final slot in sortedSlots) {
        final remainingMinutes = slotRemainingMinutes[slot.id.toString()] ?? 0;
        if (remainingMinutes >= task.estimatedMinutes) {
          final slotDate = DateTime.parse(slot.date);
          final daysFromNow = (slotDate.difference(DateTime.now()).inHours / 24).floor();
          final fitScore = 1 - (remainingMinutes - task.estimatedMinutes) / remainingMinutes;
          final priorityScore = task.priority / 5;
          final score = (10 - daysFromNow) * 2 + fitScore * 3 + priorityScore * 5;

          if (score > bestScore) {
            bestScore = score;
            bestSlot = slot;
          }
        }
      }

      if (bestSlot != null) {
        // Calculate start time based on remaining minutes
        final startMinutes = _getMinutesFromTimeString(bestSlot.startTime);
        final remainingMinutes = slotRemainingMinutes[bestSlot.id.toString()] ?? 0;
        final taskStartMinutes =
            startMinutes + (_getMinutesFromTimeString(bestSlot.endTime) - startMinutes - remainingMinutes);

        // Create deadline date
        final deadlineDate = DateTime.parse(bestSlot.date);
        final newDeadline = deadlineDate.add(Duration(
          hours: (taskStartMinutes / 60).floor(),
          minutes: taskStartMinutes % 60,
        ));

        // Update task
        if (task.priority >= 4) {
          final index = updatedPriorityTasks.indexWhere((t) => t.id == task.id);
          if (index != -1) {
            updatedPriorityTasks[index] = updatedPriorityTasks[index].copyWith(deadline: newDeadline);
            scheduledCount++;
          }
        } else {
          final index = updatedTasks.indexWhere((t) => t.id == task.id);
          if (index != -1) {
            updatedTasks[index] = updatedTasks[index].copyWith(deadline: newDeadline);
            scheduledCount++;
          }
        }

        // Update remaining time in slot
        slotRemainingMinutes[bestSlot.id.toString()] = remainingMinutes - task.estimatedMinutes;
      }
    }

    // Update the tasks in the parent widget
    for (int i = 0; i < updatedTasks.length; i++) {
      if (updatedTasks[i].deadline != widget.tasks[i].deadline) {
        widget.onTaskAdded(updatedTasks[i]);
      }
    }

    for (int i = 0; i < updatedPriorityTasks.length; i++) {
      if (updatedPriorityTasks[i].deadline != widget.priorityTasks[i].deadline) {
        widget.onTaskAdded(updatedPriorityTasks[i]);
      }
    }

    setState(() {
      _isAutoScheduleOpen = false;
    });

    if (scheduledCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully scheduled $scheduledCount tasks!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not find suitable time slots for any tasks. Try adding more time slots or reducing task durations.'),
        ),
      );
    }
  }

  int _getMinutesFromTimeString(String timeString) {
    final parts = timeString.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  List<Task> _getFilteredTasks() {
    final allTasks = [...widget.priorityTasks, ...widget.tasks];
    List<Task> filtered = [];

    switch (_filter) {
      case 'today':
        final now = DateTime.now();
        filtered = allTasks.where((task) =>
            task.deadline != null &&
            task.deadline!.day == now.day &&
            task.deadline!.month == now.month &&
            task.deadline!.year == now.year).toList();
        break;
      case 'upcoming':
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        filtered = allTasks.where((task) => task.deadline != null && task.deadline!.isAfter(tomorrow)).toList();
        break;
      case 'priority':
        filtered = allTasks.where((task) => task.priority >= 4).toList();
        break;
      case 'completed':
        filtered = allTasks.where((task) => task.isCompleted).toList();
        break;
      default:
        filtered = allTasks;
    }

    // Apply search filter if needed
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((task) =>
          task.title.toLowerCase().contains(query) ||
          (task.notes != null && task.notes!.toLowerCase().contains(query))).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          CustomScrollView(
            slivers: [
              // Header with progress
              SliverToBoxAdapter(
                child: Header(tasks: [...widget.tasks, ...widget.priorityTasks]),
              ),
              
              // Search and filters
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      SearchBar(
                        onSearch: (query) => setState(() => _searchQuery = query),
                        onFilterClick: () {},
                      ),
                      FilterTabs(
                        activeFilter: _filter,
                        onFilterChange: (filter) => setState(() => _filter = filter),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Add Task Box - NEW COMPONENT
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
                  child: AddTaskBox(
                    onAddTask: () => setState(() => _isAddTaskOpen = true),
                  ),
                ),
              ),
              
              // Auto Schedule Box - NEW COMPONENT
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                  child: AutoScheduleBox(
                    onSchedule: _autoScheduleAllTasks,
                    onClose: () {},
                    isCollapsed: true,
                  ),
                ),
              ),
              
              // Task list
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tasks = _getFilteredTasks();
                      if (tasks.isEmpty) {
                        return EmptyTaskList(
                          onAddTask: () => setState(() => _isAddTaskOpen = true),
                        );
                      }
                      
                      if (index >= tasks.length) return null;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: TaskCard(
                          task: tasks[index],
                          onComplete: (completed) => _handleTaskCompleted(tasks[index].id, completed),
                          onDelete: () => _handleTaskDeleted(tasks[index].id),
                        ),
                      );
                    },
                    childCount: _getFilteredTasks().isEmpty ? 1 : _getFilteredTasks().length,
                  ),
                ),
              ),
              
              // Bottom padding for FAB
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
          
          // Expandable Auto Scheduler Box - Vibrant and visible when opened
          if (_isAutoScheduleOpen)
            Positioned(
              bottom: 90,
              left: 16,
              right: 16,
              child: AutoScheduleBox(
                onClose: () => setState(() => _isAutoScheduleOpen = false),
                onSchedule: _autoScheduleAllTasks,
                isCollapsed: false,
              ),
            ),
          
          // Expandable FAB - Simplified to just one button
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              heroTag: 'mainFab',
              onPressed: () => setState(() => _isAddTaskOpen = true),
              backgroundColor: const Color(0xFF3B82F6),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
          
          // Confetti effect
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5,
              minBlastForce: 1,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.2,
              colors: const [
                Colors.cyan,
                Colors.purple,
                Colors.green,
                Colors.amber,
                Colors.red,
              ],
            ),
          ),
        ],
      ),
      // Here is the correct place for the bottomSheet property
      bottomSheet: _isAddTaskOpen
          ? AddTaskDialog(
              onClose: () => setState(() => _isAddTaskOpen = false),
              onAddTask: _handleAddTask,
              availableTimeSlots: _availableTimeSlots,
            )
          : null,
    );
  }
}

// NEW COMPONENT: Add Task Box - SMALLER & MORE VIBRANT
class AddTaskBox extends StatelessWidget {
  final VoidCallback onAddTask;

  const AddTaskBox({
    Key? key,
    required this.onAddTask,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70, // Reduced height
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF06B6D4)], // Emerald to Cyan gradient
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAddTask,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_task,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Add New Task',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Create and organize your tasks easily',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Auto Scheduler Box Component - SMALLER & MORE VIBRANT
class AutoScheduleBox extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onSchedule;
  final bool isCollapsed;

  const AutoScheduleBox({
    Key? key,
    required this.onClose,
    required this.onSchedule,
    required this.isCollapsed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)], // Vibrant purple to indigo gradient
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: isCollapsed ? _buildCollapsedView(context) : _buildExpandedView(),
    );
  }

  Widget _buildCollapsedView(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSchedule,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.1),
        child: SizedBox(
          height: 70, // Reduced height
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Auto Schedule',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Let AI optimize your day automatically',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedView() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Auto Scheduler',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Let AI optimize your day by automatically scheduling your tasks based on priority and available time slots.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // AI icon with glow effect
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Smart Scheduling',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prioritizes important tasks first',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Schedule My Tasks',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Empty Task List Component
class EmptyTaskList extends StatelessWidget {
  final VoidCallback onAddTask;

  const EmptyTaskList({
    Key? key,
    required this.onAddTask,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade900.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No tasks here!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add some tasks to get started',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAddTask,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Header Component
class Header extends StatelessWidget {
  final List<Task> tasks;

  const Header({
    Key? key,
    required this.tasks,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalTasks = tasks.length;
    final completedTasks = tasks.where((t) => t.isCompleted).length;
    final progress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)], // blue-700 to purple-900
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
        child: Column(
          children: [
            const Text(
              'My Smart Tasks',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(
                  width: 112,
                  height: 112,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.black.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '$completedTasks of $totalTasks tasks completed',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Filter Tabs Component
class FilterTabs extends StatelessWidget {
  final String activeFilter;
  final Function(String) onFilterChange;

  const FilterTabs({
    Key? key,
    required this.activeFilter,
    required this.onFilterChange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final filters = [
      {'id': 'all', 'label': 'All Tasks'},
      {'id': 'priority', 'label': 'Priority Tasks'},
      {'id': 'today', 'label': 'Today'},
      {'id': 'upcoming', 'label': 'Upcoming'},  
      {'id': 'completed', 'label': 'Completed'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade900),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            children: filters.map((filter) {
              final isActive = activeFilter == filter['id'];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: TextButton(
                  onPressed: () => onFilterChange(filter['id']!),
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                      isActive ? const Color(0xFF3B82F6) : Colors.transparent,
                    ),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    padding: MaterialStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  child: Text(
                    filter['label']!,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// Search Bar Component
class SearchBar extends StatelessWidget {
  final Function(String) onSearch;
  final VoidCallback onFilterClick;

  const SearchBar({
    Key? key,
    required this.onSearch,
    required this.onFilterClick,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey.shade900),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: onSearch,
                      decoration: const InputDecoration(
                        hintText: 'Search tasks...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune, color: Color(0xFF3B82F6)),
              onPressed: onFilterClick,
            ),
          ),
        ],
      ),
    );
  }
}

// Task Card Component
class TaskCard extends StatelessWidget {
  final Task task;
  final Function(bool) onComplete;
  final VoidCallback onDelete;

  const TaskCard({
    Key? key,
    required this.task,
    required this.onComplete,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (context) => TaskDetailsDialog(task: task),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: task.isCompleted
                ? [Colors.black, Colors.grey.shade900]
                : task.priority >= 4
                    ? [
                        const Color(0xFFF43F5E).withOpacity(0.1),
                        const Color(0xFFA855F7).withOpacity(0.1),
                      ]
                    : [Colors.black, Colors.grey.shade900],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: task.isCompleted
                ? Colors.transparent
                : _getPriorityBorderColor(task.priority),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            GestureDetector(
              onTap: () => onComplete(!task.isCompleted),
              child: Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 2, right: 16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.isCompleted
                      ? const Color(0xFF10B981)
                      : Colors.transparent,
                  border: Border.all(
                    color: task.isCompleted
                        ? const Color(0xFF10B981)
                        : _getPriorityColor(task.priority),
                    width: 2,
                  ),
                ),
                child: task.isCompleted
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
            
            // Task content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: task.isCompleted ? Colors.grey : Colors.white,
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  
                  if (task.estimatedMinutes > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: task.isCompleted
                                ? Colors.grey
                                : _getPriorityTextColor(task.priority),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${task.estimatedMinutes} min',
                            style: TextStyle(
                              fontSize: 12,
                              color: task.isCompleted
                                  ? Colors.grey
                                  : _getPriorityTextColor(task.priority),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Priority indicator lines
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(task.priority >= 1 ? 1.0 : 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(task.priority >= 3 ? 1.0 : 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(task.priority >= 4 ? 1.0 : 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Deadline
                  if (task.deadline != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? Colors.grey.shade900.withOpacity(0.5)
                            : _getPriorityBgColor(task.priority),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatDateTime(task.deadline!),
                        style: TextStyle(
                          fontSize: 12,
                          color: task.isCompleted
                              ? Colors.grey.shade400
                              : _getPriorityTextColor(task.priority),
                        ),
                      ),
                    ),
                  
                  // Tags
                  if (task.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: task.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.grey.shade800,
                              ),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 12,
                                color: task.isCompleted ? Colors.grey.shade500 : Colors.grey.shade400,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  
                  // Notes
                  if (task.notes != null && task.notes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        task.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: task.isCompleted ? Colors.grey.shade500 : Colors.grey.shade400,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 2,
                      ),
                    ),
                ],
              ),
            ),
            
            // Delete button
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: task.isCompleted ? Colors.grey.shade500 : const Color(0xFFF43F5E),
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return const Color(0xFF10B981); // emerald-500
      case 2:
        return const Color(0xFF14B8A6); // teal-500
      case 3:
        return const Color(0xFF06B6D4); // cyan-500
      case 4:
        return const Color(0xFFF59E0B); // amber-500
      case 5:
        return const Color(0xFFF43F5E); // rose-500
      default:
        return const Color(0xFF06B6D4); // cyan-500
    }
  }
  
  Color _getPriorityTextColor(int priority) {
    switch (priority) {
      case 1:
        return const Color(0xFF10B981); // emerald-500
      case 2:
        return const Color(0xFF14B8A6); // teal-500
      case 3:
        return const Color(0xFF06B6D4); // cyan-500
      case 4:
        return const Color(0xFFF59E0B); // amber-500
      case 5:
        return const Color(0xFFF43F5E); // rose-500
      default:
        return const Color(0xFF06B6D4); // cyan-500
    }
  }
  
  Color _getPriorityBorderColor(int priority) {
    switch (priority) {
      case 1:
        return const Color(0xFF10B981).withOpacity(0.3); // emerald-500
      case 2:
        return const Color(0xFF14B8A6).withOpacity(0.3); // teal-500
      case 3:
        return const Color(0xFF06B6D4).withOpacity(0.3); // cyan-500
      case 4:
        return const Color(0xFFF59E0B).withOpacity(0.3); // amber-500
      case 5:
        return const Color(0xFFF43F5E).withOpacity(0.3); // rose-500
      default:
        return const Color(0xFF06B6D4).withOpacity(0.3); // cyan-500
    }
  }
  
  Color _getPriorityBgColor(int priority) {
    switch (priority) {
      case 1:
        return const Color(0xFF10B981).withOpacity(0.1); // emerald-500
      case 2:
        return const Color(0xFF14B8A6).withOpacity(0.1); // teal-500
      case 3:
        return const Color(0xFF06B6D4).withOpacity(0.1); // cyan-500
      case 4:
        return const Color(0xFFF59E0B).withOpacity(0.1); // amber-500
      case 5:
        return const Color(0xFFF43F5E).withOpacity(0.1); // rose-500
      default:
        return const Color(0xFF06B6D4).withOpacity(0.1); // cyan-500
    }
  }
  
  String _formatDateTime(DateTime date) {
    return '${DateFormat.MMMd().format(date)}, ${DateFormat.jm().format(date)}';
  }
}

// Task Details Dialog
class TaskDetailsDialog extends StatelessWidget {
  final Task task;

  const TaskDetailsDialog({
    Key? key,
    required this.task,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            
            // Priority
            _buildDetailRow(
              icon: Icons.bar_chart,
              iconColor: _getPriorityTextColor(task.priority),
              label: 'Priority',
              value: _getPriorityLabel(task.priority),
              valueColor: _getPriorityTextColor(task.priority),
            ),
            
            // Estimated Time
            _buildDetailRow(
              icon: Icons.access_time,
              iconColor: Colors.purple,
              label: 'Estimated Time',
              value: '${task.estimatedMinutes} minutes',
            ),
            
            // Deadline
            if (task.deadline != null)
              _buildDetailRow(
                icon: Icons.calendar_today,
                iconColor: Colors.cyan,
                label: 'Deadline',
                value: _formatDateTime(task.deadline!),
              ),
            
            // Tags
            if (task.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.tag,
                      size: 20,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tags',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: task.tags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade800,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            // Notes
            if (task.notes != null && task.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.description,
                      size: 20,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Notes',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            task.notes!,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: iconColor,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Color _getPriorityTextColor(int priority) {
    switch (priority) {
      case 1:
        return const Color(0xFF10B981); // emerald-500
      case 2:
        return const Color(0xFF14B8A6); // teal-500
      case 3:
        return const Color(0xFF06B6D4); // cyan-500
      case 4:
        return const Color(0xFFF59E0B); // amber-500
      case 5:
        return const Color(0xFFF43F5E); // rose-500
      default:
        return const Color(0xFF06B6D4); // cyan-500
    }
  }
  
  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 1:
        return 'Very Low';
      case 2:
        return 'Low';
      case 3:
        return 'Medium';
      case 4:
        return 'High';
      case 5:
        return 'Critical';
      default:
        return 'Medium';
    }
  }
  
  String _formatDateTime(DateTime date) {
    return '${DateFormat.MMMd().format(date)}, ${DateFormat.jm().format(date)}';
  }
}

// Add Task Dialog Component
class AddTaskDialog extends StatefulWidget {
  final VoidCallback onClose;
  final Function(Task) onAddTask;
  final List<TimeSlot> availableTimeSlots;

  const AddTaskDialog({
    Key? key,
    required this.onClose,
    required this.onAddTask,
    required this.availableTimeSlots,
  }) : super(key: key);

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  int _priority = 3;
  int _estimatedMinutes = 30;
  DateTime? _selectedDate;
  String? _selectedTime;
  List<String> _selectedTags = [];
  bool _showTimeSlots = false;
  bool _showDatePicker = false;
  bool _showTimePicker = false;

  final List<String> _availableTags = ['Work', 'Personal', 'Urgent', 'Health', 'Study', 'Errands'];

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_titleController.text.trim().isEmpty) {
      return;
    }

    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      priority: _priority,
      estimatedMinutes: _estimatedMinutes,
      tags: _selectedTags,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      isCompleted: false,
    );

    if (_selectedDate != null && _selectedTime != null) {
      final parts = _selectedTime!.split(':');
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      
      final deadline = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        hours,
        minutes,
      );
      
      widget.onAddTask(task.copyWith(deadline: deadline));
    } else {
      widget.onAddTask(task);
    }
    
    widget.onClose();
  }

  void _handleAutoSchedule() {
    setState(() {
      _showTimeSlots = true;
    });
  }

  void _selectTimeSlot(TimeSlot slot) {
    final date = DateTime.parse(slot.date);
    setState(() {
      _selectedDate = date;
      _selectedTime = slot.startTime;
      _showTimeSlots = false;
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  List<DateTime> _generateDateOptions() {
    final dates = <DateTime>[];
    final today = DateTime.now();

    for (int i = 0; i < 14; i++) {
      final date = DateTime(today.year, today.month, today.day + i);
      dates.add(date);
    }

    return dates;
  }

  List<String> _generateTimeOptions() {
    final times = <String>[];
    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        final formattedHour = hour.toString().padLeft(2, '0');
        final formattedMinute = minute.toString().padLeft(2, '0');
        times.add('$formattedHour:$formattedMinute');
      }
    }
    return times;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add New Task',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _showTimeSlots
                ? _buildTimeSlotsView()
                : _showDatePicker
                    ? _buildDatePickerView()
                    : _showTimePicker
                        ? _buildTimePickerView()
                        : _buildTaskForm(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTaskForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task Name
          const Text(
            'Task Name',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'What needs to be done?',
              hintStyle: TextStyle(color: Colors.grey.shade700),
              filled: true,
              fillColor: const Color(0xFF1F2937),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 20),
          
          // Notes
          const Text(
            'Notes',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'Add notes (optional)',
              hintStyle: TextStyle(color: Colors.grey.shade700),
              filled: true,
              fillColor: const Color(0xFF1F2937),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          
          // Priority
          const Text(
            'Priority',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _priority.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            onChanged: (value) {
              setState(() {
                _priority = value.round();
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Low',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF10B981),
                  ),
                ),
                const Text(
                  'Medium',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF06B6D4),
                  ),
                ),
                const Text(
                  'High',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFF43F5E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Estimated Time
          const Text(
            'Estimated Time',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _estimatedMinutes.toDouble(),
            min: 5,
            max: 240,
            divisions: 47,
            onChanged: (value) {
              setState(() {
                _estimatedMinutes = value.round();
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '5 min',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '$_estimatedMinutes min',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                const Text(
                  '4 hours',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Schedule
          const Text(
            'Schedule',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showDatePicker = true),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(12),
                      border: _selectedDate != null
                          ? Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: _selectedDate != null ? const Color(0xFF06B6D4) : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedDate != null
                                ? DateFormat('MMM d, yyyy').format(_selectedDate!)
                                : 'Select Date',
                            style: TextStyle(
                              color: _selectedDate != null ? Colors.white : Colors.grey,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showTimePicker = true),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(12),
                      border: _selectedTime != null
                          ? Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 18,
                          color: _selectedTime != null ? const Color(0xFF06B6D4) : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedTime ?? 'Select Time',
                          style: TextStyle(
                            color: _selectedTime != null ? Colors.white : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Tags
          const Text(
            'Tags',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () => _toggleTag(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF06B6D4).withOpacity(0.2)
                        : const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF06B6D4)
                          : Colors.grey.shade700,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF06B6D4) : Colors.grey,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _handleAutoSchedule,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Auto Schedule'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _titleController.text.trim().isNotEmpty ? _handleSubmit : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF06B6D4).withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTimeSlotsView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Time Slot',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => setState(() => _showTimeSlots = false),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: widget.availableTimeSlots.length,
            itemBuilder: (context, index) {
              final slot = widget.availableTimeSlots[index];
              final slotDate = DateTime.parse(slot.date);
              final formattedDate = DateFormat('E, MMM d').format(slotDate);
              final today = _isToday(slot.date);
              
              return GestureDetector(
                onTap: () => _selectTimeSlot(slot),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: today ? const Color(0xFF06B6D4).withOpacity(0.1) : const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: today ? const Color(0xFF06B6D4).withOpacity(0.3) : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: today ? const Color(0xFF06B6D4).withOpacity(0.2) : Colors.grey.shade800.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          color: today ? const Color(0xFF06B6D4) : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${slot.startTime} - ${slot.endTime}',
                              style: TextStyle(
                                color: today ? const Color(0xFF06B6D4) : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: today ? const Color(0xFF06B6D4).withOpacity(0.2) : Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${getMinutesFromTimeString(slot.endTime) - getMinutesFromTimeString(slot.startTime)} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: today ? const Color(0xFF06B6D4) : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildDatePickerView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Date',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => setState(() => _showDatePicker = false),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _generateDateOptions().length,
            itemBuilder: (context, index) {
              final date = _generateDateOptions()[index];
              final isToday = date.day == DateTime.now().day &&
                  date.month == DateTime.now().month &&
                  date.year == DateTime.now().year;
              final isSelected = _selectedDate != null &&
                  date.day == _selectedDate!.day &&
                  date.month == _selectedDate!.month &&
                  date.year == _selectedDate!.year;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                    _showDatePicker = false;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF06B6D4)
                        : isToday
                            ? const Color(0xFF06B6D4).withOpacity(0.1)
                            : const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('E').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? const Color(0xFF06B6D4)
                                  : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? const Color(0xFF06B6D4)
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildTimePickerView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Time',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => setState(() => _showTimePicker = false),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _generateTimeOptions().length,
            itemBuilder: (context, index) {
              final time = _generateTimeOptions()[index];
              final isSelected = time == _selectedTime;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTime = time;
                    _showTimePicker = false;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF06B6D4) : const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      time,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  bool _isToday(String dateString) {
    final today = DateTime.now();
    return dateString == '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }
}