enum ConclaveStatus {
  draft,

  /// The default for a newly created conclave: it exists, but the admin has not
  /// opened the doors yet.
  registrationNotOpen,

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

  /// Start and end are deliberately flexible — either may be unset.
  final DateTime? startTime;
  final DateTime? endTime;

  final List<String> chiefGuests;

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
    this.startTime,
    this.endTime,
    this.chiefGuests = const [],
    this.personsPerTable = 7,
    this.roundCount = 6,
    this.isRegistered = false,
    this.userRole,
    this.userTableNumber,
  });

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    // Firestore Timestamp
    return (v as dynamic).toDate() as DateTime?;
  }

  factory Conclave.fromFirestore(Map<String, dynamic> data, String id) {
    return Conclave(
      id: id,
      name: data['name'] ?? 'Unnamed Conclave',
      venueLocation: data['venueLocation'] ?? 'Unknown Venue',
      date: _toDate(data['date']) ?? DateTime.now(),
      startTime: _toDate(data['startTime']),
      endTime: _toDate(data['endTime']),
      chiefGuests: ((data['chiefGuests'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
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
      startTime: startTime,
      endTime: endTime,
      chiefGuests: chiefGuests,
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
