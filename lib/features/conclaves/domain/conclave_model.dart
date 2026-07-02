enum ConclaveStatus {
  draft,
  registrationOpen,
  registrationClosed,
  snapshotted,
  scheduled,
  locked,
  running,
  completed,
  cancelled
}

enum ConclaveRole {
  member,
  captain
}

class Conclave {
  final String id;
  final String name;
  final String venueLocation;
  final DateTime date;
  final ConclaveStatus status;
  final bool isRegistrationOpen;

  // Additional details
  final int personsPerTable;
  final int roundCount;

  // User's specific info for this conclave (if registered)
  final bool isRegistered;
  final ConclaveRole? userRole;
  final int? userTableNumber;

  Conclave({
    required this.id,
    required this.name,
    required this.venueLocation,
    required this.date,
    required this.status,
    required this.isRegistrationOpen,
    this.personsPerTable = 7,
    this.roundCount = 6,
    this.isRegistered = false,
    this.userRole,
    this.userTableNumber,
  });
}

// Mock Data
final List<Conclave> mockConclaves = [
  Conclave(
    id: 'c1',
    name: 'Guntur Mega Conclave 2026',
    venueLocation: 'ITC Grand, Guntur',
    date: DateTime.now().add(const Duration(days: 2)),
    status: ConclaveStatus.registrationOpen,
    isRegistrationOpen: true,
  ),
  Conclave(
    id: 'c2',
    name: 'Vijayawada Founders Meet',
    venueLocation: 'Novotel, Vijayawada',
    date: DateTime.now().add(const Duration(hours: 1)),
    status: ConclaveStatus.locked,
    isRegistrationOpen: false,
    isRegistered: true,
    userRole: ConclaveRole.member,
  ),
  Conclave(
    id: 'c3',
    name: 'Annual BNI Connect',
    venueLocation: 'Hyatt Place, Hyderabad',
    date: DateTime.now().subtract(const Duration(days: 10)),
    status: ConclaveStatus.completed,
    isRegistrationOpen: false,
    isRegistered: true,
    userRole: ConclaveRole.captain,
    userTableNumber: 4,
  ),
];
