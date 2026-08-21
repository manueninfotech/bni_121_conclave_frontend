import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../auth/data/auth_repository.dart';

/// One referral — given or received — with the counterpart and where it
/// happened. Self-scoped: the backend only ever returns the caller's own.
/// The business-outcome lifecycle a referral moves through, driven by the
/// receiver.
enum ReferralOutcome { open, accepted, closed, notClosed }

ReferralOutcome _outcomeFrom(String s) => switch (s) {
      'accepted' => ReferralOutcome.accepted,
      'closed' => ReferralOutcome.closed,
      'not_closed' => ReferralOutcome.notClosed,
      _ => ReferralOutcome.open,
    };

extension ReferralOutcomeX on ReferralOutcome {
  String get wire => switch (this) {
        ReferralOutcome.open => 'open',
        ReferralOutcome.accepted => 'accepted',
        ReferralOutcome.closed => 'closed',
        ReferralOutcome.notClosed => 'not_closed',
      };

  String get label => switch (this) {
        ReferralOutcome.open => 'Open',
        ReferralOutcome.accepted => 'Accepted',
        ReferralOutcome.closed => 'Closed',
        ReferralOutcome.notClosed => "Didn't work out",
      };
}

class ReferralEntry {
  final String id;
  final String conclaveId;
  final String conclaveName;
  final int roundNumber;
  final String otherName;
  final String otherBusinessName;
  final String notes;
  final ReferralOutcome outcome;
  final int closedAmount;
  final String outcomeNote;
  final DateTime? createdAt;

  const ReferralEntry({
    required this.id,
    required this.conclaveId,
    required this.conclaveName,
    required this.roundNumber,
    required this.otherName,
    required this.otherBusinessName,
    required this.notes,
    required this.outcome,
    required this.closedAmount,
    required this.outcomeNote,
    required this.createdAt,
  });

  factory ReferralEntry.fromJson(Map<String, dynamic> j) => ReferralEntry(
        id: (j['id'] ?? '') as String,
        conclaveId: (j['conclaveId'] ?? '') as String,
        conclaveName: (j['conclaveName'] ?? '') as String,
        roundNumber: (j['roundNumber'] as num?)?.toInt() ?? 0,
        otherName: (j['otherName'] ?? '') as String,
        otherBusinessName: (j['otherBusinessName'] ?? '') as String,
        notes: (j['notes'] ?? '') as String,
        outcome: _outcomeFrom((j['outcome'] ?? 'open') as String),
        closedAmount: (j['closedAmount'] as num?)?.toInt() ?? 0,
        outcomeNote: (j['outcomeNote'] ?? '') as String,
        createdAt: DateTime.tryParse((j['createdAt'] ?? '') as String)?.toLocal(),
      );
}

class MyReferrals {
  final List<ReferralEntry> given;
  final List<ReferralEntry> received;

  const MyReferrals({required this.given, required this.received});

  static const empty = MyReferrals(given: [], received: []);
}

final myReferralsRepositoryProvider = Provider<MyReferralsRepository>((ref) {
  return MyReferralsRepository(FirebaseAuth.instance);
});

final myReferralsProvider = FutureProvider<MyReferrals>((ref) {
  ref.watch(authStateProvider.select((a) => a.asData?.value?.uid));
  return ref.watch(myReferralsRepositoryProvider).fetch();
});

class MyReferralsRepository {
  final FirebaseAuth _auth;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  MyReferralsRepository(this._auth);

  Future<MyReferrals> fetch() async {
    final user = _auth.currentUser;
    if (user == null) return MyReferrals.empty;

    final token = await user.getIdToken();
    try {
      final res = await _dio.get(
        '${ApiConfig.baseUrl}/me/referrals',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data as Map;
      List<ReferralEntry> parse(String key) =>
          ((data[key] as List?) ?? const [])
              .map((e) => ReferralEntry.fromJson((e as Map).cast<String, dynamic>()))
              .toList();
      return MyReferrals(given: parse('given'), received: parse('received'));
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['error'] ?? '').toString()
          : '';
      throw Exception(msg.isNotEmpty
          ? msg
          : 'Could not load your referrals. Check your connection.');
    }
  }

  /// Records the outcome of a referral this member RECEIVED. `amount` (rupees)
  /// applies only when [outcome] is closed.
  Future<void> updateOutcome({
    required String conclaveId,
    required String referralId,
    required ReferralOutcome outcome,
    int amount = 0,
    String note = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('You are not signed in.');

    final token = await user.getIdToken();
    try {
      await _dio.patch(
        '${ApiConfig.baseUrl}/conclaves/$conclaveId/referrals/$referralId/outcome',
        data: {'outcome': outcome.wire, 'amount': amount, 'note': note},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data['error'] ?? '').toString()
          : '';
      throw Exception(msg.isNotEmpty ? msg : 'Could not update the referral.');
    }
  }
}
