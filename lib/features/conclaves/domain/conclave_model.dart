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

  /// Coerces whatever a date field holds into a DateTime.
  ///
  /// The same field arrives in different shapes depending on who wrote it: the
  /// backend writes a Firestore Timestamp, the admin UI writes an ISO-8601
  /// String ("2026-07-27T05:28:15.127Z"), and some paths write epoch millis.
  /// The old version assumed Timestamp and called `.toDate()` on everything — a
  /// single string date threw NoSuchMethodError, which errored the whole
  /// conclaves stream, so NOBODY could load ANY conclave and the app looked dead
  /// right after login. Handle every shape, and never throw: a single unparseable
  /// value must not take down the list.
  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v)?.toLocal();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v).toLocal();
    // Firestore Timestamp exposes toDate(); anything else we can't read.
    try {
      final d = (v as dynamic).toDate();
      return d is DateTime ? d : null;
    } catch (_) {
      return null;
    }
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
