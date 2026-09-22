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

/// The registration fee and where to pay it, as set by the admin panel.
///
/// All of it is optional: a conclave with no `paymentDetails`, or a zero fee, is
/// free and registers in one tap. When a fee is set, the app shows it and offers
/// Razorpay (online) or the UPI/bank details below (offline).
class PaymentDetails {
  /// Fee in whole rupees. 0 means free.
  final int registrationFee;
  final String? upiId;
  final String? upiQrImageUrl;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? accountHolderName;

  const PaymentDetails({
    this.registrationFee = 0,
    this.upiId,
    this.upiQrImageUrl,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.accountHolderName,
  });

  bool get hasFee => registrationFee > 0;

  /// True when there's enough to actually pay offline (a UPI id or a full bank
  /// row). Without this the offline option would show a fee and no way to pay it.
  bool get hasOfflineDetails =>
      (upiId != null && upiId!.trim().isNotEmpty) ||
      (accountNumber != null && accountNumber!.trim().isNotEmpty);

  static String? _str(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory PaymentDetails.fromMap(Map<String, dynamic> m) {
    return PaymentDetails(
      registrationFee: (m['registrationFee'] as num?)?.round() ?? 0,
      upiId: _str(m['upiId']),
      upiQrImageUrl: _str(m['upiQrImageUrl']),
      bankName: _str(m['bankName']),
      accountNumber: _str(m['accountNumber']),
      ifscCode: _str(m['ifscCode']),
      accountHolderName: _str(m['accountHolderName']),
    );
  }
}

class Conclave {
  final String id;
  final String name;
  final String venueLocation;
  final DateTime date;

  /// Last day of a multi-day event. Null for a single-day conclave (use [date]).
  final DateTime? endDate;

  final ConclaveStatus status;
  final bool isRegistrationOpen;

  /// Null when the conclave is free (no fee configured).
  final PaymentDetails? paymentDetails;

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
    this.endDate,
    required this.status,
    required this.isRegistrationOpen,
    this.startTime,
    this.endTime,
    this.chiefGuests = const [],
    this.personsPerTable = 7,
    this.roundCount = 6,
    this.paymentDetails,
    this.isRegistered = false,
    this.userRole,
    this.userTableNumber,
  });

  /// Status corrected for the passage of time.
  ///
  /// Nothing writes `completed` when an event's day simply passes, and the app
  /// reads the stored `status` straight from Firestore — so a finished conclave
  /// would otherwise sit in the "live" list forever (the bug where a conclave
  /// marked ended in the admin panel still showed as ongoing in the app). Once
  /// the event's last day is over, treat it as completed. A conclave running
  /// today keeps its stored status, so a live event still reads as live.
  ConclaveStatus get effectiveStatus {
    if (status == ConclaveStatus.completed ||
        status == ConclaveStatus.cancelled) {
      return status;
    }
    final lastDay = endDate ?? date;
    final endOfLastDay =
        DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59);
    if (DateTime.now().isAfter(endOfLastDay)) return ConclaveStatus.completed;
    return status;
  }

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

  /// Combines a time-of-day string ("10:00", "1:00 PM") with [base]'s calendar
  /// day. The backend stores start/end as "HH:mm" strings (not full datetimes),
  /// so [_toDate] can't read them — this anchors the clock time onto the event
  /// day for display and for the end-of-event check. Full datetimes/Timestamps
  /// fall through to [_toDate].
  static DateTime? _timeOfDayOn(dynamic raw, DateTime base) {
    if (raw is! String) return null;
    final m =
        RegExp(r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])?$').firstMatch(raw.trim());
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final mer = m.group(3)?.toUpperCase();
    if (mer == 'PM' && h < 12) h += 12;
    if (mer == 'AM' && h == 12) h = 0;
    return DateTime(base.year, base.month, base.day, h, min);
  }

  factory Conclave.fromFirestore(Map<String, dynamic> data, String id) {
    final date = _toDate(data['date']) ?? DateTime.now();
    final endDate = _toDate(data['endDate']);
    return Conclave(
      id: id,
      name: data['name'] ?? 'Unnamed Conclave',
      venueLocation: data['venueLocation'] ?? 'Unknown Venue',
      date: date,
      endDate: endDate,
      startTime:
          _timeOfDayOn(data['startTime'], date) ?? _toDate(data['startTime']),
      endTime: _timeOfDayOn(data['endTime'], endDate ?? date) ??
          _toDate(data['endTime']),
      chiefGuests: ((data['chiefGuests'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      status: ConclaveStatus.fromString(data['status'] ?? 'draft'),
      isRegistrationOpen: data['isRegistrationOpen'] ?? false,
      personsPerTable: data['personsPerTable'] ?? 7,
      roundCount: data['roundCount'] ?? 6,
      paymentDetails: data['paymentDetails'] is Map
          ? PaymentDetails.fromMap(
              Map<String, dynamic>.from(data['paymentDetails'] as Map))
          : null,
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
      paymentDetails: paymentDetails,
      isRegistered: isRegistered ?? this.isRegistered,
      userRole: userRole ?? this.userRole,
      userTableNumber: userTableNumber ?? this.userTableNumber,
    );
  }
}
