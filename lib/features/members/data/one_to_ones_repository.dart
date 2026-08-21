import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../auth/data/auth_repository.dart';

enum OneToOneStatus { pending, accepted, declined, cancelled }

OneToOneStatus _statusFrom(String s) => switch (s) {
      'accepted' => OneToOneStatus.accepted,
      'declined' => OneToOneStatus.declined,
      'cancelled' => OneToOneStatus.cancelled,
      _ => OneToOneStatus.pending,
    };

extension OneToOneStatusX on OneToOneStatus {
  String get wire => name;
  String get label => switch (this) {
        OneToOneStatus.pending => 'Pending',
        OneToOneStatus.accepted => 'Accepted',
        OneToOneStatus.declined => 'Declined',
        OneToOneStatus.cancelled => 'Cancelled',
      };
}

/// A one-to-one meeting between two members.
class OneToOne {
  final String id;

  /// True if the signed-in member SENT this request; false if they received it.
  final bool sent;
  final String otherUserId;
  final String otherName;
  final String otherBusinessName;
  final String? otherPhotoUrl;
  final DateTime? proposedAt;
  final String location;
  final String note;
  final OneToOneStatus status;

  const OneToOne({
    required this.id,
    required this.sent,
    required this.otherUserId,
    required this.otherName,
    required this.otherBusinessName,
    required this.otherPhotoUrl,
    required this.proposedAt,
    required this.location,
    required this.note,
    required this.status,
  });

  factory OneToOne.fromJson(Map<String, dynamic> j) => OneToOne(
        id: (j['id'] ?? '') as String,
        sent: (j['direction'] ?? '') == 'sent',
        otherUserId: (j['otherUserId'] ?? '') as String,
        otherName: (j['otherName'] ?? '') as String,
        otherBusinessName: (j['otherBusinessName'] ?? '') as String,
        otherPhotoUrl: (j['otherPhotoUrl'] as String?)?.isEmpty ?? true
            ? null
            : j['otherPhotoUrl'] as String,
        proposedAt:
            DateTime.tryParse((j['proposedAt'] ?? '') as String)?.toLocal(),
        location: (j['location'] ?? '') as String,
        note: (j['note'] ?? '') as String,
        status: _statusFrom((j['status'] ?? 'pending') as String),
      );

  bool get isUpcoming =>
      status == OneToOneStatus.accepted &&
      proposedAt != null &&
      proposedAt!.isAfter(DateTime.now());
}

final oneToOnesRepositoryProvider = Provider<OneToOnesRepository>((ref) {
  return OneToOnesRepository(FirebaseAuth.instance);
});

final myOneToOnesProvider = FutureProvider<List<OneToOne>>((ref) {
  ref.watch(authStateProvider.select((a) => a.asData?.value?.uid));
  return ref.watch(oneToOnesRepositoryProvider).list();
});

class OneToOnesRepository {
  final FirebaseAuth _auth;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  OneToOnesRepository(this._auth);

  Future<String> _token() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('You are not signed in.');
    return (await user.getIdToken())!;
  }

  Options _auth$(String t) => Options(headers: {'Authorization': 'Bearer $t'});

  Future<List<OneToOne>> list() async {
    if (_auth.currentUser == null) return const [];
    try {
      final res = await _dio.get(
        '${ApiConfig.baseUrl}/me/one-to-ones',
        options: _auth$(await _token()),
      );
      final list = ((res.data as Map)['oneToOnes'] as List?) ?? const [];
      return list
          .map((e) => OneToOne.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Could not load your 1-2-1s.'));
    }
  }

  Future<void> propose({
    required String toUserId,
    required DateTime proposedAt,
    String location = '',
    String note = '',
  }) async {
    try {
      await _dio.post(
        '${ApiConfig.baseUrl}/me/one-to-ones',
        data: {
          'toUserId': toUserId,
          'proposedAt': proposedAt.toUtc().toIso8601String(),
          'location': location,
          'note': note,
        },
        options: _auth$(await _token()),
      );
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Could not send the request.'));
    }
  }

  Future<void> updateStatus(String id, OneToOneStatus status) async {
    try {
      await _dio.patch(
        '${ApiConfig.baseUrl}/me/one-to-ones/$id',
        data: {'status': status.wire},
        options: _auth$(await _token()),
      );
    } on DioException catch (e) {
      throw Exception(_msg(e, 'Could not update the 1-2-1.'));
    }
  }

  String _msg(DioException e, String fallback) {
    final m = e.response?.data is Map
        ? (e.response?.data['error'] ?? '').toString()
        : '';
    return m.isNotEmpty ? m : fallback;
  }
}
