enum ConclaveStatus {
  draft,
  registrationOpen,
  registrationClosed,
  snapshotted,
  scheduled,
  locked,
  running,
  completed,
  cancelled;

  static ConclaveStatus fromString(String status) {
    return ConclaveStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => ConclaveStatus.draft,
    );
  }
}

enum ConclaveRole {
  member,
  captain;

  static ConclaveRole fromString(String role) {
    return ConclaveRole.values.firstWhere(
      (e) => e.name == role,
      orElse: () => ConclaveRole.member,
    );
  }
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
  factory Conclave.fromFirestore(Map<String, dynamic> data, String id) {
    return Conclave(
      id: id,
      name: data['name'] ?? 'Unnamed Conclave',
      venueLocation: data['venueLocation'] ?? 'Unknown Venue',
      date: data['date'] != null ? (data['date'] as dynamic).toDate() : DateTime.now(),
      status: ConclaveStatus.fromString(data['status'] ?? 'draft'),
      isRegistrationOpen: data['isRegistrationOpen'] ?? false,
      personsPerTable: data['personsPerTable'] ?? 7,
      roundCount: data['roundCount'] ?? 6,
    );
  }

  // We can copyWith to add user-specific data after fetching
  Conclave copyWith({
    bool? isRegistered,
    ConclaveRole? userRole,
    int? userTableNumber,
  }) {
    return Conclave(
      id: id,
      name: name,
      venueLocation: venueLocation,
      date: date,
      status: status,
      isRegistrationOpen: isRegistrationOpen,
      personsPerTable: personsPerTable,
      roundCount: roundCount,
      isRegistered: isRegistered ?? this.isRegistered,
      userRole: userRole ?? this.userRole,
      userTableNumber: userTableNumber ?? this.userTableNumber,
    );
  }
}
