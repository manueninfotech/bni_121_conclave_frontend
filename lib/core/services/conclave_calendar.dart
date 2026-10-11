import 'package:add_2_calendar/add_2_calendar.dart';

import '../../features/conclaves/domain/conclave_model.dart';
import 'local_notifications.dart';

/// "Add to calendar" + a scheduled app-side reminder for a conclave a member
/// has registered for. Works on iOS and Android.
class ConclaveCalendar {
  static DateTime eventStart(Conclave c) =>
      c.startTime ?? DateTime(c.date.year, c.date.month, c.date.day, 9, 0);

  static DateTime eventEnd(Conclave c) {
    final start = eventStart(c);
    final end = c.endTime;
    return (end != null && end.isAfter(start))
        ? end
        : start.add(const Duration(hours: 2));
  }

  /// Opens the native calendar editor pre-filled with the conclave. Returns
  /// whether the platform add-event flow was launched.
  static Future<bool> addToCalendar(Conclave c) {
    final event = Event(
      title: c.name,
      description: 'BNI 1-2-1 Conclave',
      location: c.venueLocation,
      startDate: eventStart(c),
      endDate: eventEnd(c),
      iosParams: const IOSParams(reminder: Duration(hours: 1)),
    );
    return Add2Calendar.addEvent2Cal(event);
  }

  /// Schedules an app-side reminder ~1 hour before the conclave starts (or at
  /// the start if that's already within the hour). Never throws.
  static Future<void> scheduleReminder(Conclave c) {
    final start = eventStart(c);
    final hourBefore = start.subtract(const Duration(hours: 1));
    return LocalNotifications.scheduleConclaveReminder(
      conclaveId: c.id,
      conclaveName: c.name,
      remindAt: hourBefore.isAfter(DateTime.now()) ? hourBefore : start,
    );
  }
}
