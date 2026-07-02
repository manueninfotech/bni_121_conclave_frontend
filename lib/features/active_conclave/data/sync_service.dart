import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_db.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(localDbProvider);
  final service = SyncService(db);
  
  ref.onDispose(() {
    service.stopSyncTimer();
  });
  
  return service;
});

class SyncService {
  final LocalDatabase _db;
  final Dio _dio;
  Timer? _syncTimer;
  bool _isSyncing = false;

  // Change to your machine's local IP or 10.0.2.2 if testing on Android emulator
  static const String baseUrl = 'http://localhost:3000/api'; 

  SyncService(this._db) : _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 5)));

  /// Starts the automatic background sync (every 30 seconds)
  void startSyncTimer(String conclaveId) {
    if (_syncTimer != null && _syncTimer!.isActive) return;
    
    // Initial sync right away
    syncNow(conclaveId);
    
    // Then periodic
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
      final unsyncedAttendance = await _db.getUnsyncedAttendance();
      final unsyncedReferrals = await _db.getUnsyncedReferrals();

      if (unsyncedAttendance.isEmpty && unsyncedReferrals.isEmpty) {
        // Nothing to sync
        _isSyncing = false;
        return;
      }

      final payload = {
        'attendance': unsyncedAttendance,
        'referrals': unsyncedReferrals,
      };

      // 10.0.2.2 is the alias for localhost on Android Emulator
      final targetHost = defaultTargetPlatform == TargetPlatform.android 
          ? 'http://10.0.2.2:3000/api'
          : 'http://localhost:3000/api';
      
      final response = await _dio.post(
        '$targetHost/conclaves/$conclaveId/sync',
        data: payload,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        final List<String> syncedAttendanceIds = List<String>.from(data['syncedAttendanceIds'] ?? []);
        final List<String> syncedReferralIds = List<String>.from(data['syncedReferralIds'] ?? []);

        // Mark as synced locally so they don't upload again
        await _db.markAttendanceSynced(syncedAttendanceIds);
        await _db.markReferralsSynced(syncedReferralIds);
        
        debugPrint('Successfully synced ${syncedAttendanceIds.length} attendance records and ${syncedReferralIds.length} referrals.');
      } else {
        debugPrint('Sync failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Sync error: $e');
      // Just fail silently and try again next tick
    } finally {
      _isSyncing = false;
    }
  }
}
