class ProductivityEntry {
  DateTime date;
  int tasksCompleted;
  int focusMinutes;
  int distractionCount;
  double averageMood;

  ProductivityEntry({
    required this.date, 
    required this.tasksCompleted, 
    required this.focusMinutes,
    this.distractionCount = 0,
    this.averageMood = 3.0,
  });
}