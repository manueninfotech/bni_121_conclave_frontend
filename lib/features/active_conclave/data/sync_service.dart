import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/time/server_clock.dart';
import 'local_db.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(localDbProvider);
  final service = SyncService(db, FirebaseAuth.instance, ref.watch(serverClockProvider));

  ref.onDispose(service.stopSyncTimer);

  return service;
});

/// Pushes offline captures up to the server and pulls received referrals down.
///
/// The push direction carries the invariant that matters: a row is only marked
/// `synced` locally once the server has confirmed it actually committed. If the
/// server cannot be reached, or its write fails, the rows stay on the device and
/// are retried. Nothing is ever acknowledged optimistically.
class SyncService {
  final LocalDatabase _db;
  final FirebaseAuth _auth;
  final ServerClock _clock;
  final Dio _dio;
  Timer? _syncTimer;
  bool _isSyncing = false;

  /// 10.0.2.2 is the Android emulator's alias for the host machine's localhost.
  ///
  /// TODO: this needs to become runtime-configurable before a real event — see
  /// OFFLINE_ATTENDANCE_AND_SYNC.md §5 (venue LAN), currently parked.
  static String get baseUrl => defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:3000/api'
      : 'http://localhost:3000/api';

  SyncService(this._db, this._auth, this._clock)
      : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));

  /// Starts the automatic background sync (every 30 seconds).
  void startSyncTimer(String conclaveId) {
    if (_syncTimer != null && _syncTimer!.isActive) return;

    syncNow(conclaveId);

    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      syncNow(conclaveId);
    });
  }

  void stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> syncNow(String conclaveId) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final unsyncedAttendance = await _db.getUnsyncedAttendance();
      final unsyncedReferrals = await _db.getUnsyncedReferrals();

      // Even with nothing to push we still call: this is also how referrals
      // given to us on other people's phones come DOWN, and how we correct our
      // clock against the server.
      final sentAt = DateTime.now(); // t0
      final response = await _dio.post(
        '$baseUrl/conclaves/$conclaveId/sync',
        data: {
          'userId': uid,
          'attendance': unsyncedAttendance,
          'referrals': unsyncedReferrals,
        },
      );
      final receivedAt = DateTime.now(); // t3

      if (response.statusCode != 200) {
        debugPrint('Sync failed with status: ${response.statusCode}');
        return;
      }

      final data = response.data as Map<String, dynamic>;

      // Correct our clock BEFORE anything else. Round gating depends on it, and
      // a device whose clock disagrees with the server would open or close the
      // round at the wrong moment.
      final t1 = DateTime.tryParse((data['serverReceivedAt'] ?? '') as String);
      final t2 = DateTime.tryParse((data['serverSentAt'] ?? '') as String);
      if (t1 != null && t2 != null) {
        await _clock.syncWith(
          sentAt: sentAt,
          serverReceivedAt: t1.toLocal(),
          serverSentAt: t2.toLocal(),
          receivedAt: receivedAt,
        );
      }

      // Only ids the server actually committed come back here.
      final syncedAttendanceIds =
          List<String>.from(data['syncedAttendanceIds'] ?? const []);
      final syncedReferralIds =
          List<String>.from(data['syncedReferralIds'] ?? const []);

      await _db.markAttendanceSynced(syncedAttendanceIds);
      await _db.markReferralsSynced(syncedReferralIds);

      // Referrals other people gave to this user.
      final received = (data['newReferralsReceived'] as List?) ?? const [];
      if (received.isNotEmpty) {
        await _db.upsertReceivedReferrals(
          received.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        );
      }

      debugPrint(
        'Synced ${syncedAttendanceIds.length} attendance, '
        '${syncedReferralIds.length} referrals; '
        'pulled ${received.length} received referrals.',
      );
    } catch (e) {
      // Offline is the expected state at the venue, not an error. Rows stay
      // unsynced and the next tick retries.
      debugPrint('Sync error (will retry): $e');
    } finally {
      _isSyncing = false;
    }
  }
}
