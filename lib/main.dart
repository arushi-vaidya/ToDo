import 'package:flutter/material.dart';

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
    });
  }

  void _deleteTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
  }

  void _moveToPriorityTasks() {
    final currentDateTime = DateTime.now();
    final expiredTasks = _tasks.where((task) => task.deadline != null && task.deadline!.isBefore(currentDateTime) && !task.isCompleted).toList();
    setState(() {
      for (var task in expiredTasks) {
        _priorityTasks.add(task);
        _tasks.remove(task);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _moveToPriorityTasks();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Helper'),
        elevation: 0,
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
                      hintStyle: TextStyle(color: Colors.white),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white10,
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _addTask(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.cyan, // Cyan color for the circle
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () {
                      if (_textController.text.isNotEmpty) {
                        _addTask(_textController.text);
                      }
                    },
                    iconSize: 30, // Adjust size if necessary
                  ),
                )

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
            child: ListView.builder(
              itemCount: _priorityTasks.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  elevation: 5,
                  color: Colors.grey[900],
                  child: ListTile(
                    leading: Checkbox(
                      value: _priorityTasks[index].isCompleted,
                      onChanged: (bool? value) {
                        setState(() {
                          _priorityTasks[index].isCompleted = value!;
                        });
                      },
                    ),
                    title: Text(
                      _priorityTasks[index].title,
                      style: TextStyle(
                        decoration: _priorityTasks[index].isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: _priorityTasks[index].isCompleted
                            ? Colors.grey
                            : Colors.white,
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
            child: Text(
              'Tasks',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  elevation: 5,
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
                            decoration: _tasks[index].isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: _tasks[index].isCompleted
                                ? Colors.grey
                                : Colors.white,
                          ),
                        ),
                        if (_tasks[index].deadline != null)
                          Text(
                            'Due: ${_tasks[index].deadline!.day}/${_tasks[index].deadline!.month}/${_tasks[index].deadline!.year} ${_tasks[index].deadline!.hour}:${_tasks[index].deadline!.minute}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.redAccent),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: () {
                            _editTaskDateTime(index);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: () {
                            _deleteTask(index);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
