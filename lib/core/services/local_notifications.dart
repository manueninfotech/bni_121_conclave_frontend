import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

/// On-device notifications the app raises itself.
///
/// Used for the 1-2-1 reminder: the backend sends a data-only push when a
/// meeting enters its final hour, and this turns it into a warm, STICKY
/// notification that counts itself down to the meeting time — Android's own
/// chronometer does the ticking, so it stays live without the app or server
/// updating it every second.
class LocalNotifications {
  LocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'one_to_one_reminders';
  static const _brand = Color(0xFFC41230);

  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    const android =
        AndroidInitializationSettings('@drawable/ic_stat_conclave');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          'Meeting reminders',
          description: 'Countdowns to your one-to-one meetings',
          importance: Importance.high,
        ));
    _ready = true;
  }

  /// A sticky notification that counts down to a 1-2-1. Safe to call repeatedly
  /// for the same [id] — it refreshes rather than stacks.
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
      _channelId,
      'Meeting reminders',
      channelDescription: 'Countdowns to your one-to-one meetings',
      importance: Importance.high,
      priority: Priority.high,
      color: _brand,
      // Sticky and calm: stays put, but only makes a sound the first time.
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      category: AndroidNotificationCategory.event,
      // The live countdown — Android ticks it down to `when` on its own.
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

  /// Turns a data push into the countdown notification. Shared by the foreground
  /// and background handlers so both raise an identical sticky reminder.
  static Future<void> handleReminderData(Map<String, dynamic> data) async {
    if (data['type'] != 'one_to_one_reminder') return;
    final at = DateTime.tryParse((data['proposedAt'] ?? '') as String);
    if (at == null) return;
    final id = ((data['id'] ?? '') as String);
    await showOneToOneCountdown(
      id: id.hashCode & 0x7fffffff,
      otherName: (data['otherName'] ?? 'a member') as String,
      proposedAt: at.toLocal(),
      location: (data['location'] ?? '') as String,
    );
  }
}
