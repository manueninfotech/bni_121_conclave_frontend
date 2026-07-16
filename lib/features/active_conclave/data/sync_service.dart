import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/time/server_clock.dart';
import 'local_db.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(localDbProvider);
  final service = SyncService(db, FirebaseAuth.instance, ref.watch(serverClockProvider));

  ref.onDispose(service.dispose);

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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;
  bool _wasOffline = false;

  /// Supplied at build time via --dart-define=API_BASE_URL. See [ApiConfig].
  static String get baseUrl => ApiConfig.baseUrl;

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

  /// Drain pending records the moment the network comes back.
  ///
  /// The 30-second timer above only runs while the active-round screen is open
  /// and only knows about ONE conclave. At the venue the network comes and goes,
  /// and a member who leaves that screen (or backgrounds the app) would otherwise
  /// sit on unsynced records indefinitely — even with signal restored.
  ///
  /// This watches connectivity for the whole app lifetime and flushes everything
  /// outstanding, for every conclave, whenever we transition offline -> online.
  void startConnectivityWatch() {
    if (_connectivitySub != null) return;

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline =
          results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);

      if (isOnline && _wasOffline) {
        debugPrint('Network is back — flushing pending records.');
        syncAllPending();
      }
      _wasOffline = !isOnline;
    });

    // Connectivity only reports CHANGES, so an app that starts up already online
    // with records left over from a previous session would never hear an event.
    // Flush once at startup too.
    syncAllPending();
  }

  /// Push everything still outstanding, across every conclave.
  ///
  /// Having connectivity does not mean the SERVER is reachable (captive portal,
  /// backend down, wrong host). syncNow() already treats failure as "leave it
  /// unsynced and retry", so a wasted attempt here is harmless.
  Future<void> syncAllPending() async {
    if (_auth.currentUser == null) return;

    final pending = await _db.pendingConclaveIds();
    if (pending.isEmpty) return;

    debugPrint('Flushing ${pending.length} conclave(s) with pending records.');
    for (final conclaveId in pending) {
      await syncNow(conclaveId);
    }
  }

  void dispose() {
    stopSyncTimer();
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<void> syncNow(String conclaveId) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // /sync is authenticated: the server takes the caller's identity from this
      // token and ignores anything in the body, because a uid in a request body
      // is just a string the caller typed. Without it every sync 401s and the
      // records retry forever.
      final token = await user.getIdToken();

      // Only THIS conclave's rows. The endpoint is per-conclave and validates
      // every record against that conclave's schedule, so a row belonging to a
      // different event would be rejected as "not at your table" — and then
      // acknowledged as unfixable, quietly destroying it.
      final unsyncedAttendance = await _db.getUnsyncedAttendance(conclaveId: conclaveId);
      final unsyncedReferrals = await _db.getUnsyncedReferrals(conclaveId: conclaveId);

      // Even with nothing to push we still call: this is also how referrals
      // given to us on other people's phones come DOWN, and how we correct our
      // clock against the server.
      final sentAt = DateTime.now(); // t0
      final response = await _dio.post(
        '$baseUrl/conclaves/$conclaveId/sync',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          // Read 4xx rather than throwing, so a rejection can be logged instead
          // of vanishing into the catch as an unexplained "sync error".
          validateStatus: (s) => s != null && s < 500,
        ),
        data: {
          'attendance': unsyncedAttendance,
          'referrals': unsyncedReferrals,
        },
      );
      final receivedAt = DateTime.now(); // t3

      if (response.statusCode != 200) {
        final body = response.data;
        debugPrint(
          'Sync rejected (${response.statusCode}): '
          '${body is Map ? body['error'] : body}',
        );
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
