/// Referrals.
///
/// A referral is a promise of business: person A tells person B "I'll give you
/// business". That is ONE fact, seen from two sides — it appears in A's *given*
/// list and, automatically, in B's *received* list. The app never asks B to
/// confirm anything.
///
/// When A refers B *and* B refers A, the pair is **mutual**: each of them has
/// both given to and received from the other.
///
/// Offline consequence worth understanding: a referral A gives is created on
/// A's phone. B's phone cannot know about it until it has been synced through
/// the server. So `given` is always available offline, but `received` only
/// appears after a sync. That is inherent — the promise is made on one device.
library;

/// One referral, in whichever direction the reader cares about.
class Referral {
  /// Stable id. Server-assigned for received; locally generated for given.
  final String id;
  final String conclaveId;
  final int roundNumber;

  final String fromUserId;
  final String toUserId;

  /// The other party's display details. Populated for received referrals (the
  /// server joins them in); for given referrals the app already knows the
  /// person from the table roster.
  final String otherName;
  final String otherBusinessName;

  final String notes;
  final DateTime createdAt;

  /// Whether this record has made it to the server yet. Only meaningful for
  /// referrals this user gave — received ones came *from* the server.
  final bool synced;

  const Referral({
    required this.id,
    required this.conclaveId,
    required this.roundNumber,
    required this.fromUserId,
    required this.toUserId,
    required this.otherName,
    required this.otherBusinessName,
    required this.notes,
    required this.createdAt,
    required this.synced,
  });
}

/// Everything a user needs to see about their referrals in one conclave.
class ReferralSummary {
  /// Referrals this user gave to other people.
  final List<Referral> given;

  /// Referrals other people gave to this user.
  final List<Referral> received;

  /// The other party's uid for every pair where BOTH directions exist.
  final Set<String> mutualUids;

  const ReferralSummary({
    required this.given,
    required this.received,
    required this.mutualUids,
  });

  int get givenCount => given.length;
  int get receivedCount => received.length;

  /// Number of people this user exchanged referrals with in both directions.
  int get mutualCount => mutualUids.length;

  /// Every referral this user is party to, in either direction.
  int get totalCount => givenCount + receivedCount;

  /// Referrals given that have not yet reached the server. This is what the
  /// post-conclave "did my data survive?" view keys off.
  int get unsyncedGivenCount => given.where((r) => !r.synced).length;

  bool isMutualWith(String uid) => mutualUids.contains(uid);

  static const empty = ReferralSummary(given: [], received: [], mutualUids: {});
}

/// Builds the summary, deriving the mutual set.
///
/// Mutual = the same pair of people referred each other. Direction of each
/// individual record does not matter beyond that; what matters is that both
/// directions are present.
ReferralSummary buildReferralSummary({
  required List<Referral> given,
  required List<Referral> received,
}) {
  final gaveTo = given.map((r) => r.toUserId).toSet();
  final receivedFrom = received.map((r) => r.fromUserId).toSet();

  return ReferralSummary(
    given: given,
    received: received,
    mutualUids: gaveTo.intersection(receivedFrom),
  );
}
