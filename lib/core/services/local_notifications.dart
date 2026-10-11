import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../firebase_options.dart';
import '../config/api_config.dart';
import '../navigation.dart';

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
  static const channelReferrals = 'referrals';
  static const channelGeneral = 'general';

  static const _brand = Color(0xFFC41230);

  static const _acceptAction = 'onetoone_accept';
  static const _declineAction = 'onetoone_decline';

  /// iOS groups action buttons under a category the notification references,
  /// where Android attaches them to the notification directly. This is the
  /// iOS-side equivalent of the Accept/Decline actions on a 1-2-1 request.
  static const _oneToOneCategory = 'onetoone_request';

  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@drawable/ic_stat_conclave');
    // iOS: ask for permission up front and declare the Accept/Decline category
    // so those buttons appear on a 1-2-1 request in the tray, just like Android.
    final darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          _oneToOneCategory,
          actions: [
            DarwinNotificationAction.plain(_acceptAction, 'Accept'),
            DarwinNotificationAction.plain(
              _declineAction,
              'Decline',
              options: {DarwinNotificationActionOption.destructive},
            ),
          ],
        ),
      ],
    );
    await _plugin.initialize(
      settings: InitializationSettings(android: android, iOS: darwin),
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
      AndroidNotificationChannel(channelReferrals, 'Referrals',
          description: 'When a member passes you a referral',
          importance: Importance.high),
      AndroidNotificationChannel(channelGeneral, 'General',
          description: 'Other updates', importance: Importance.defaultImportance),
    ]) {
      await android$?.createNotificationChannel(c);
    }
    _ready = true;
  }

  // ---- Generic foreground alert -------------------------------------------

  /// Mirror a plain push (round started, referral, or any other notification
  /// message) into the tray. FCM does NOT display a notification message while
  /// the app is in the foreground, so without this the user sees nothing while
  /// they have the app open — which is exactly when a round starts. [channel]
  /// picks the Android channel (falls back to General).
  static Future<void> showMessage({
    required String title,
    required String body,
    String channel = channelGeneral,
    String? payload,
  }) async {
    await init();
    final channelName = switch (channel) {
      channelRoundAlerts => 'Round alerts',
      channelReferrals => 'Referrals',
      channelOneToOnes => '1-2-1s',
      _ => 'General',
    };
    final android = AndroidNotificationDetails(
      channel,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      color: _brand,
      styleInformation: BigTextStyleInformation(body),
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.show(
      // A fresh id each time so alerts stack rather than replace each other.
      id: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: android, iOS: ios),
      payload: payload,
    );
  }

  // ---- Conclave reminder (scheduled) --------------------------------------

  static int _conclaveReminderId(String conclaveId) =>
      'reminder_$conclaveId'.hashCode & 0x7fffffff;

  /// Schedules a one-off reminder before a conclave the member registered for.
  /// Safe to call repeatedly — it replaces any existing reminder for the same
  /// conclave. Never throws (scheduling failures must not break registration).
  static Future<void> scheduleConclaveReminder({
    required String conclaveId,
    required String conclaveName,
    required DateTime remindAt,
  }) async {
    try {
      await init();
      if (remindAt.isBefore(DateTime.now())) return;
      const android = AndroidNotificationDetails(
        channelReminders,
        'Meeting reminders',
        channelDescription: 'Reminders before your conclaves',
        importance: Importance.high,
        priority: Priority.high,
        color: _brand,
      );
      const ios = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      await _plugin.zonedSchedule(
        id: _conclaveReminderId(conclaveId),
        title: 'Conclave coming up 📅',
        body: '$conclaveName is almost here — get ready to network.',
        scheduledDate: tz.TZDateTime.from(remindAt, tz.local),
        notificationDetails: const NotificationDetails(android: android, iOS: ios),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'conclave:$conclaveId',
      );
    } catch (_) {
      // Permissions, a past date on a slow clock, etc. — never block the user.
    }
  }

  // ---- Live round sticky (ongoing, self-counting-down) --------------------

  /// A single, stable id so every update replaces the same ongoing notification
  /// rather than stacking a new one each round.
  static const _roundStickyId = 0x5713C07;

  /// Shows (or updates) the ongoing "live round" notification — the Zomato-style
  /// status card that keeps the round, the member's table and a live countdown in
  /// the shade while the phone is pocketed. Android only: it leans on an ongoing
  /// chronometer notification, which iOS has no equivalent for (a Live Activity is
  /// the iOS answer, handled separately). A no-op elsewhere; never throws.
  ///
  /// [segmentEnd] is the wall-clock time the current countdown reaches zero — the
  /// end of the talking phase, or of the walk-to-your-next-table transition. The
  /// system drives the per-second countdown from it, so the app doesn't have to
  /// re-post every tick; it only updates when the round, phase or speaker changes.
  static Future<void> showRoundSticky({
    required int round,
    required int totalRounds,
    required int tableNumber,
    required String line,
    required DateTime segmentEnd,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await init();
      final countdown = segmentEnd.isAfter(DateTime.now());
      final title = 'Round $round of $totalRounds · Table $tableNumber';
      final android = AndroidNotificationDetails(
        channelRoundAlerts,
        'Round alerts',
        channelDescription: 'When a conclave round starts',
        // Low importance: an ongoing status that updates as speakers change must
        // not buzz or pop a heads-up each time — it just sits in the shade.
        importance: Importance.low,
        priority: Priority.low,
        color: _brand,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        category: AndroidNotificationCategory.event,
        when: countdown ? segmentEnd.millisecondsSinceEpoch : null,
        showWhen: countdown,
        usesChronometer: countdown,
        chronometerCountDown: countdown,
        styleInformation: BigTextStyleInformation(line, contentTitle: title),
      );
      await _plugin.show(
        id: _roundStickyId,
        title: title,
        body: line,
        notificationDetails: NotificationDetails(android: android),
        payload: 'conclave_round',
      );
    } catch (_) {
      // An ongoing notification is a convenience; its failure must never affect
      // the running round on screen.
    }
  }

  /// Clears the live-round sticky — on leaving the active-round screen, or when
  /// the conclave is over. Safe to call when none is showing.
  static Future<void> cancelRoundSticky() async {
    try {
      await _plugin.cancel(id: _roundStickyId);
    } catch (_) {}
  }

  // ---- 1-2-1 reminder (scheduled before a confirmed meeting) --------------

  static int _oneToOneReminderId(String meetingId) =>
      'onetoone_reminder_$meetingId'.hashCode & 0x7fffffff;

  /// Schedules a reminder ~15 minutes before a CONFIRMED 1-2-1 (or at the meeting
  /// time if it's already inside that window). Idempotent — a stable id per
  /// meeting means re-scheduling just replaces the pending one, so it's safe to
  /// call every time the 1-2-1 list loads. Never throws.
  static Future<void> scheduleOneToOneReminder({
    required String meetingId,
    required String otherName,
    required DateTime proposedAt,
    String location = '',
  }) async {
    try {
      await init();
      final lead = proposedAt.subtract(const Duration(minutes: 15));
      final remindAt = lead.isAfter(DateTime.now()) ? lead : proposedAt;
      if (remindAt.isBefore(DateTime.now())) return; // meeting already passed
      final place = location.trim().isEmpty ? '' : ' at ${location.trim()}';
      final timeLabel = DateFormat('h:mm a').format(proposedAt);
      const android = AndroidNotificationDetails(
        channelReminders,
        'Meeting reminders',
        channelDescription: 'Countdowns to your one-to-one meetings',
        importance: Importance.high,
        priority: Priority.high,
        color: _brand,
      );
      const ios = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      await _plugin.zonedSchedule(
        id: _oneToOneReminderId(meetingId),
        title: '☕ 1-2-1 with $otherName',
        body: 'Coming up at $timeLabel$place — a good moment to line up a referral.',
        scheduledDate: tz.TZDateTime.from(remindAt, tz.local),
        notificationDetails: const NotificationDetails(android: android, iOS: ios),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: meetingId,
      );
    } catch (_) {
      // Permissions, a cancelled meeting, a past time — never surface to the user.
    }
  }

  /// Cancels a previously scheduled 1-2-1 reminder (the meeting was declined or
  /// cancelled). Safe when none is pending.
  static Future<void> cancelOneToOneReminder(String meetingId) async {
    try {
      await _plugin.cancel(id: _oneToOneReminderId(meetingId));
    } catch (_) {}
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
    const ios = DarwinNotificationDetails(
      categoryIdentifier: _oneToOneCategory,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.show(
      id: meetingId.hashCode & 0x7fffffff,
      title: '🤝 1-2-1 request',
      body: '$fromName would like a one-to-one with you.',
      notificationDetails: NotificationDetails(android: android, iOS: ios),
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
    // iOS has no ongoing/chronometer notification, so the countdown can't be a
    // live sticky there; it still surfaces as a normal alert with the details.
    final ios = DarwinNotificationDetails(
      subtitle: place.isEmpty ? null : place.trim(),
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _plugin.show(
      id: id,
      title: '☕ 1-2-1 with $otherName',
      body: 'Starting soon$place',
      notificationDetails: NotificationDetails(android: android, iOS: ios),
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

  // ---- Taps & action responses --------------------------------------------

  static void _onResponse(NotificationResponse r) {
    if (r.actionId == _acceptAction || r.actionId == _declineAction) {
      _act(r);
      return;
    }
    // A body tap on one of our local notifications (a 1-2-1 request or the
    // reminder) — open the 1-2-1s screen.
    openFromNotification(const {'type': 'one_to_one'});
  }

  /// If the app was launched by tapping one of our local notifications, route to
  /// the right screen. Call once after the first frame.
  static Future<void> handleAppLaunch() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (!(details?.didNotificationLaunchApp ?? false)) return;
    final resp = details!.notificationResponse;
    if (resp != null && resp.actionId == null) {
      openFromNotification(const {'type': 'one_to_one'});
    }
  }
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
