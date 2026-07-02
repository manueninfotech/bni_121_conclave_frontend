class TableSeat {
  final String userId;
  final String name;
  final String businessName;
  final String category;
  bool isPresent; // For captains to mark

  TableSeat({
    required this.userId,
    required this.name,
    required this.businessName,
    required this.category,
    this.isPresent = false,
  });
}

class ActiveRound {
  final int roundNumber;
  final int tableNumber;
  final DateTime startTime;
  final Duration activeDuration; // usually 10 mins
  final Duration transitionDuration; // usually 5 mins
  final List<TableSeat> seats;

  ActiveRound({
    required this.roundNumber,
    required this.tableNumber,
    required this.startTime,
    this.activeDuration = const Duration(minutes: 10),
    this.transitionDuration = const Duration(minutes: 5),
    required this.seats,
  });
}

// Mock Data for the Active UI
final mockActiveRound = ActiveRound(
  roundNumber: 1,
  tableNumber: 4,
  startTime: DateTime.now().subtract(const Duration(minutes: 2)), // Started 2 mins ago
  seats: [
    TableSeat(userId: 'u1', name: 'Samba', businessName: 'Manuen Infotech', category: 'Software Development'),
    TableSeat(userId: 'u2', name: 'Ravi Kumar', businessName: 'Ravi Builders', category: 'Construction'),
    TableSeat(userId: 'u3', name: 'Anita Reddy', businessName: 'Anita Designs', category: 'Interior Design'),
    TableSeat(userId: 'u4', name: 'Priya Sharma', businessName: 'Priya Catering', category: 'Food & Beverage'),
    TableSeat(userId: 'u5', name: 'Vikram Singh', businessName: 'Vikram Legal', category: 'Legal Services'),
  ],
);
