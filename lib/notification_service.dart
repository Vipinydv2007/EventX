import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ─────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────

enum ReminderInterval {
  oneHour(Duration(hours: 1), '1 hour before'),
  threeHours(Duration(hours: 3), '3 hours before'),
  oneDay(Duration(days: 1), '1 day before'),
  custom(Duration.zero, 'Custom time…');

  const ReminderInterval(this.offset, this.label);
  final Duration offset;
  final String label;
}

enum ReminderResult {
  scheduled,
  pastTime,
  permissionDenied,
  unsupportedPlatform,
}

// ─────────────────────────────────────────────
// NotificationService singleton
// ─────────────────────────────────────────────

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Must be called once in main() before runApp().
  Future<void> initialize() async {
    if (kIsWeb) return; // No-op on web
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
    developer.log('NotificationService initialized ✅');
  }

  /// Requests notification permissions.
  /// Returns true if granted (or already granted), false if denied or web.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    try {
      // Android
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted =
            await androidPlugin.requestNotificationsPermission() ?? false;
        developer.log('Android notification permission: $granted');
        return granted;
      }

      // iOS
      final iosPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
        developer.log('iOS notification permission: $granted');
        return granted;
      }

      return true; // Other platforms (macOS, Linux) — assume granted
    } catch (e) {
      developer.log('Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Parses a date string (DD/MM/YYYY) and time string (HH:MM AM/PM)
  /// into a combined DateTime. Returns null if parsing fails.
  static DateTime? parseEventDateTime(String date, String time) {
    try {
      if (date.isEmpty) return null;

      final dateParts = date.split('/');
      if (dateParts.length != 3) return null;

      final day = int.tryParse(dateParts[0]);
      final month = int.tryParse(dateParts[1]);
      final year = int.tryParse(dateParts[2]);

      if (day == null || month == null || year == null) return null;

      if (time.isEmpty) {
        // Default to midnight if no time provided
        return DateTime(year, month, day, 0, 0);
      }

      // Parse HH:MM AM/PM
      final timeParts = time.trim().split(' ');
      if (timeParts.length != 2) return null;

      final hmParts = timeParts[0].split(':');
      if (hmParts.length != 2) return null;

      int? hour = int.tryParse(hmParts[0]);
      final minute = int.tryParse(hmParts[1]);
      final period = timeParts[1].toUpperCase();

      if (hour == null || minute == null) return null;
      if (period != 'AM' && period != 'PM') return null;

      // Convert to 24-hour
      if (period == 'AM' && hour == 12) hour = 0;
      if (period == 'PM' && hour != 12) hour += 12;

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      developer.log('parseEventDateTime error: $e');
      return null;
    }
  }

  /// Schedules a local notification for [eventId] at [fireTime].
  Future<ReminderResult> scheduleReminder({
    required int eventId,
    required String eventTitle,
    required DateTime fireTime,
  }) async {
    if (kIsWeb) return ReminderResult.unsupportedPlatform;

    final granted = await requestPermissions();
    if (!granted) return ReminderResult.permissionDenied;

    if (fireTime.isBefore(DateTime.now())) return ReminderResult.pastTime;

    try {
      final notificationId = _notificationId(eventId);
      final tzFireTime = tz.TZDateTime.from(fireTime, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'event_reminders',
        'Event Reminders',
        channelDescription: 'Reminders for upcoming events',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.zonedSchedule(
        notificationId,
        '⏰ Event Reminder',
        '$eventTitle is starting soon!',
        tzFireTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      developer.log(
          'Reminder scheduled for event $eventId at $fireTime (id: $notificationId)');
      return ReminderResult.scheduled;
    } catch (e) {
      developer.log('Error scheduling reminder: $e');
      return ReminderResult.permissionDenied; // Treat unexpected errors as denied
    }
  }

  /// Cancels any scheduled notification for [eventId].
  Future<void> cancelReminder(int eventId) async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(_notificationId(eventId));
      developer.log('Reminder cancelled for event $eventId');
    } catch (e) {
      developer.log('Error cancelling reminder: $e');
    }
  }

  /// Derives a stable notification ID from an event ID.
  int _notificationId(int eventId) => eventId % 2147483647;
}
