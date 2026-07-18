import 'package:backpackhelp/reminder_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const _schoolNotificationId = 700001;
  static const _generalNotificationBaseId = 701000;

  static const _androidDetails = AndroidNotificationDetails(
    'backpack_reminders',
    'Backpack reminders',
    channelDescription: 'School checklist and general backpack reminders',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _notificationDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  static Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    await _setLocalTimeZone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(settings: initializationSettings);
    _initialized = true;
  }

  static Future<void> scheduleAll({bool requestPermissions = false}) async {
    await initialize();
    if (requestPermissions) {
      await _requestPermissions();
    }
    await _notifications.cancelAll();

    final schoolSettings = await ReminderStore.loadSchoolSettings();
    if (schoolSettings.enabled) {
      await _scheduleSchoolReminder(schoolSettings);
    }

    final reminders = await ReminderStore.loadGeneralReminders();
    for (var i = 0; i < reminders.length; i++) {
      final reminder = reminders[i];
      if (!reminder.enabled) continue;
      await _scheduleGeneralReminder(reminder, _generalNotificationBaseId + i);
    }
  }

  static Future<void> _scheduleSchoolReminder(
    SchoolReminderSettings settings,
  ) async {
    final start = settings.startMinutesOfDay;
    final remindAt = (start - settings.leadMinutes) % (24 * 60);
    final hour = remindAt ~/ 60;
    final minute = remindAt % 60;
    final startTime = formatReminderTime(
      settings.startHour,
      settings.startMinute,
    );

    await _notifications.zonedSchedule(
      id: _schoolNotificationId,
      title: 'School starts at $startTime',
      body: 'Check your backpack list before you leave.',
      scheduledDate: _nextDailyTime(hour: hour, minute: minute),
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'school-checklist',
    );
  }

  static Future<void> _scheduleGeneralReminder(
    GeneralReminder reminder,
    int notificationId,
  ) async {
    await _notifications.zonedSchedule(
      id: notificationId,
      title: reminder.title,
      body: reminder.note.isEmpty ? 'Backpack Help reminder' : reminder.note,
      scheduledDate: _nextDailyTime(
        hour: reminder.hour,
        minute: reminder.minute,
      ),
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'general-reminder:${reminder.id}',
    );
  }

  static tz.TZDateTime _nextDailyTime({
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static Future<void> _setLocalTimeZone() async {
    if (kIsWeb) return;

    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }
  }

  static Future<void> _requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }
}
