import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import '../../firebase_options.dart';
import '../config/api_config.dart';

/// On-device notifications the app raises itself — which is what unlocks
/// notification CHANNELS (user-toggleable categories) and ACTION BUTTONS
/// (Accept / Decline straight from the tray), neither of which a plain
/// server-rendered FCM notification can do.
class LocalNotifications {
  LocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Channels — the categories a member can turn on/off in system settings.
  static const channelRoundAlerts = 'round_alerts';
  static const channelOneToOnes = 'one_to_ones';
  static const channelReminders = 'one_to_one_reminders';

  static const _brand = Color(0xFFC41230);

  static const _acceptAction = 'onetoone_accept';
  static const _declineAction = 'onetoone_decline';

  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@drawable/ic_stat_conclave');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundResponse,
    );

    final android$ = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    for (final c in const [
      AndroidNotificationChannel(channelRoundAlerts, 'Round alerts',
          description: 'When a conclave round starts',
          importance: Importance.high),
      AndroidNotificationChannel(channelOneToOnes, '1-2-1s',
          description: 'One-to-one meeting requests and responses',
          importance: Importance.high),
      AndroidNotificationChannel(channelReminders, 'Meeting reminders',
          description: 'Countdowns to your one-to-one meetings',
          importance: Importance.high),
    ]) {
      await android$?.createNotificationChannel(c);
    }
    _ready = true;
  }

  // ---- 1-2-1 request (with Accept / Decline actions) ----------------------

  static Future<void> showOneToOneRequest({
    required String meetingId,
    required String fromName,
  }) async {
    await init();
    final android = const AndroidNotificationDetails(
      channelOneToOnes,
      '1-2-1s',
      channelDescription: 'One-to-one meeting requests and responses',
      importance: Importance.high,
      priority: Priority.high,
      color: _brand,
      category: AndroidNotificationCategory.social,
      actions: [
        AndroidNotificationAction(_acceptAction, 'Accept',
            showsUserInterface: false, cancelNotification: true),
        AndroidNotificationAction(_declineAction, 'Decline',
            showsUserInterface: false, cancelNotification: true),
      ],
    );
    await _plugin.show(
      id: meetingId.hashCode & 0x7fffffff,
      title: '🤝 1-2-1 request',
      body: '$fromName would like a one-to-one with you.',
      notificationDetails: NotificationDetails(android: android),
      payload: meetingId,
    );
  }

  static Future<void> handleRequestData(Map<String, dynamic> data) async {
    if (data['type'] != 'one_to_one_request') return;
    final id = (data['id'] ?? '') as String;
    if (id.isEmpty) return;
    await showOneToOneRequest(
      meetingId: id,
      fromName: (data['fromName'] ?? 'A member') as String,
    );
  }

  // ---- 1-2-1 reminder (sticky, self-counting-down) ------------------------

  static Future<void> showOneToOneCountdown({
    required int id,
    required String otherName,
    required DateTime proposedAt,
    String location = '',
  }) async {
    await init();
    final place = location.isEmpty ? '' : ' at $location';
    final timeLabel = DateFormat('EEE, h:mm a').format(proposedAt);
    final big =
        "You're meeting $otherName$place, $timeLabel. A good moment to bring "
        'a talking point — and maybe a referral to pass.';

    final android = AndroidNotificationDetails(
      channelReminders,
      'Meeting reminders',
      channelDescription: 'Countdowns to your one-to-one meetings',
      importance: Importance.high,
      priority: Priority.high,
      color: _brand,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      category: AndroidNotificationCategory.event,
      when: proposedAt.millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: true,
      styleInformation: BigTextStyleInformation(
        big,
        contentTitle: '☕ 1-2-1 with $otherName',
      ),
    );
    await _plugin.show(
      id: id,
      title: '☕ 1-2-1 with $otherName',
      body: 'Starting soon$place',
      notificationDetails: NotificationDetails(android: android),
    );
  }

  static Future<void> handleReminderData(Map<String, dynamic> data) async {
    if (data['type'] != 'one_to_one_reminder') return;
    final at = DateTime.tryParse((data['proposedAt'] ?? '') as String);
    if (at == null) return;
    final id = (data['id'] ?? '') as String;
    await showOneToOneCountdown(
      id: id.hashCode & 0x7fffffff,
      otherName: (data['otherName'] ?? 'a member') as String,
      proposedAt: at.toLocal(),
      location: (data['location'] ?? '') as String,
    );
  }

  // ---- Action responses ---------------------------------------------------

  static void _onResponse(NotificationResponse r) => _act(r);
}

/// Foreground/background action handler. Top-level and vm:entry-point so it can
/// run in the isolate that flutter_local_notifications spawns when an action is
/// tapped while the app is killed.
@pragma('vm:entry-point')
void notificationBackgroundResponse(NotificationResponse r) => _act(r);

void _act(NotificationResponse r) {
  final meetingId = r.payload ?? '';
  if (meetingId.isEmpty) return;
  switch (r.actionId) {
    case 'onetoone_accept':
      _respondToOneToOne(meetingId, 'accepted');
    case 'onetoone_decline':
      _respondToOneToOne(meetingId, 'declined');
  }
}

/// Applies a 1-2-1 response straight from the notification — no UI. Works from a
/// background isolate: it brings up Firebase and the backend URL on its own.
Future<void> _respondToOneToOne(String meetingId, String status) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await user.getIdToken();
    await Dio().patch(
      '${ApiConfig.baseUrl}/me/one-to-ones/$meetingId',
      data: {'status': status},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  } catch (e) {
    debugPrint('1-2-1 notification action failed: $e');
  }
}
