class TimeSlot {
  final int id;  // The 'id' property, to be used as a key
  final String date;
  final String startTime;
  final String endTime;

  // Constructor for the TimeSlot class
  TimeSlot({
    required this.id,  // id is required
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  // Method to calculate minutes from a time string ("HH:mm")
  static int calculateMinutes(String time) {
    List<String> parts = time.split(':');
    int hours = int.parse(parts[0]);
    int minutes = int.parse(parts[1]);
    return hours * 60 + minutes;
  }

  // Method to get the remaining minutes for this time slot
  int getRemainingMinutes() {
    int startMinutes = calculateMinutes(startTime);
    int endMinutes = calculateMinutes(endTime);
    return endMinutes - startMinutes;
  }
}

void main() {
  // List of TimeSlot objects
  List<TimeSlot> slots = [
    TimeSlot(id: 1, date: "2025-04-15", startTime: "08:00", endTime: "09:00"),
    TimeSlot(id: 2, date: "2025-04-15", startTime: "09:00", endTime: "10:00"),
  ];

  // Map to store remaining minutes, where key is the 'id' of the time slot
  Map<int, int> slotRemainingMinutes = {};

  // Iterate over each slot to calculate remaining minutes and store it in the map
  for (TimeSlot slot in slots) {
    // Access 'id' of the slot and calculate the remaining minutes
    slotRemainingMinutes[slot.id] = slot.getRemainingMinutes();
  }

  // Print out the remaining minutes for each slot
  print(slotRemainingMinutes);  // Expected output: {1: 60, 2: 60}
}
