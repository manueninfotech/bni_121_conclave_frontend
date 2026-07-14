import 'active_conclave_models.dart';

/// The QR code a member presents so their captain can mark them present.
///
/// Attendance is captured by the CAPTAIN scanning the MEMBER — not the other
/// way around. That direction is deliberate: the scanning device is the one the
/// record lands on, so scanning inward means every record for a table collects
/// on a single phone. The captain can then see the table's roll with no network
/// at all, and only ~1 device per table (rather than every member's phone) ever
/// needs to reach the server.
///
/// Payload is deliberately plain text, not JSON: it must survive being printed
/// on a name badge, and stay small enough to scan reliably from paper.
///
///   `BNI121|1|<conclaveId>|<uid>`
///
/// The uid is not a secret (it identifies, it does not authenticate) and the
/// captain is standing at the table, so a static code is sufficient. There is no
/// spoofing risk worth a rotating token here.
class AttendanceQr {
  static const String prefix = 'BNI121';
  static const int version = 1;

  final String conclaveId;
  final String uid;

  const AttendanceQr({required this.conclaveId, required this.uid});

  String encode() => '$prefix|$version|$conclaveId|$uid';

  /// Parses a scanned string. Returns null for anything that isn't one of our
  /// codes — the scanner will happily read any QR in the room.
  static AttendanceQr? tryParse(String raw) {
    final parts = raw.trim().split('|');
    if (parts.length != 4) return null;
    if (parts[0] != prefix) return null;
    if (int.tryParse(parts[1]) != version) return null;

    final conclaveId = parts[2];
    final uid = parts[3];
    if (conclaveId.isEmpty || uid.isEmpty) return null;

    return AttendanceQr(conclaveId: conclaveId, uid: uid);
  }
}

/// Why a scan was rejected, or that it was accepted.
enum ScanResult {
  /// Not one of our QR codes at all.
  notOurCode,

  /// One of our codes, but for a different conclave.
  wrongConclave,

  /// A valid member, but not seated at this captain's table this round. This is
  /// the one that actually matters at a busy venue: it stops a captain from
  /// accidentally marking someone from the next table over.
  notAtThisTable,

  /// The captain scanned their own code.
  selfScan,

  /// The round is not in its active phase, so attendance is closed.
  roundClosed,

  accepted,
}

/// Validates a raw scan against the captain's current table.
///
/// Pure: no I/O, no widgets — the whole rule set is testable without a camera.
class ScanOutcome {
  final ScanResult result;

  /// The seat that was scanned, when [result] is [ScanResult.accepted].
  final TableSeat? seat;

  const ScanOutcome(this.result, [this.seat]);

  bool get isAccepted => result == ScanResult.accepted;
}

ScanOutcome validateScan({
  required String raw,
  required ActiveRound round,
  required DateTime now,
}) {
  final parsed = AttendanceQr.tryParse(raw);
  if (parsed == null) return const ScanOutcome(ScanResult.notOurCode);

  if (parsed.conclaveId != round.conclaveId) {
    return const ScanOutcome(ScanResult.wrongConclave);
  }

  if (!round.canRecordAt(now)) {
    return const ScanOutcome(ScanResult.roundClosed);
  }

  if (parsed.uid == round.currentUserId) {
    return const ScanOutcome(ScanResult.selfScan);
  }

  for (final seat in round.seats) {
    if (seat.userId == parsed.uid) {
      return ScanOutcome(ScanResult.accepted, seat);
    }
  }

  return const ScanOutcome(ScanResult.notAtThisTable);
}

String scanMessage(ScanOutcome outcome) {
  switch (outcome.result) {
    case ScanResult.accepted:
      return 'Marked ${outcome.seat!.name} present.';
    case ScanResult.notOurCode:
      return 'Not a conclave QR code.';
    case ScanResult.wrongConclave:
      return 'That code is for a different conclave.';
    case ScanResult.notAtThisTable:
      return 'That person is not at your table this round.';
    case ScanResult.selfScan:
      return 'That is your own code.';
    case ScanResult.roundClosed:
      return 'The round is closed — attendance can no longer be recorded.';
  }
}
