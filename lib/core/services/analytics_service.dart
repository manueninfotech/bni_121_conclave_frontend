import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Product analytics, in one place.
///
/// Every screen and flow logs through here rather than touching
/// [FirebaseAnalytics] directly, so event names and parameters stay consistent
/// and typo-free. All calls swallow their own errors — analytics must never
/// break a user flow.
///
/// These are USAGE events (what members do), not tracking: no third-party
/// advertising, no data brokers. The App Privacy label must declare "Usage Data"
/// + "Diagnostics", NOT used for tracking.
class Analytics {
  Analytics._();

  static final FirebaseAnalytics instance = FirebaseAnalytics.instance;

  /// Attach to the router so screen_view is logged on every navigation.
  static final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: instance);

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    try {
      await instance.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('analytics "$name" failed: $e');
    }
  }

  /// Identify the member so events, retention and funnels tie to a person.
  static Future<void> setUser({String? uid, String? membership}) async {
    try {
      await instance.setUserId(id: uid);
      if (membership != null && membership.isNotEmpty) {
        await instance.setUserProperty(name: 'membership', value: membership);
      }
    } catch (_) {}
  }

  // ---- Auth ---------------------------------------------------------------
  static Future<void> signUp(String method) async {
    try {
      await instance.logSignUp(signUpMethod: method);
    } catch (_) {}
  }

  static Future<void> login(String method) async {
    try {
      await instance.logLogin(loginMethod: method);
    } catch (_) {}
  }

  // ---- Conclave -----------------------------------------------------------
  static Future<void> conclaveRegister(String conclaveId, {required bool paid}) =>
      _log('conclave_register', {'conclave_id': conclaveId, 'paid': paid});

  static Future<void> paymentCompleted(String conclaveId, num amount) =>
      _log('payment_completed', {'conclave_id': conclaveId, 'value': amount});

  // ---- Live round: attendance via QR --------------------------------------
  static Future<void> qrScan(String conclaveId) =>
      _log('qr_scan', {'conclave_id': conclaveId});

  static Future<void> attendanceMarked(String conclaveId, {required bool present}) =>
      _log('attendance_marked', {'conclave_id': conclaveId, 'present': present});

  // ---- Referrals ----------------------------------------------------------
  static Future<void> referralPassed() => _log('referral_passed');

  static Future<void> referralOutcome(String outcome, {num amount = 0}) =>
      _log('referral_outcome', {'outcome': outcome, 'value': amount});

  // ---- One-to-ones --------------------------------------------------------
  /// [action] is one of: requested, accepted, declined, cancelled.
  static Future<void> oneToOne(String action) =>
      _log('one_to_one_$action');
}
