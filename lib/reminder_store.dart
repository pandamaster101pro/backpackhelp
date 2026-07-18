import 'dart:convert';

import 'package:backpackhelp/checklist_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSchoolReminderSettingsKey = 'school_reminder_settings';
const _kGeneralRemindersKey = 'general_reminders';

class SchoolReminderSettings {
  final bool enabled;
  final int startHour;
  final int startMinute;
  final int leadMinutes;

  const SchoolReminderSettings({
    this.enabled = false,
    this.startHour = 7,
    this.startMinute = 0,
    this.leadMinutes = 60,
  });

  int get startMinutesOfDay => startHour * 60 + startMinute;

  SchoolReminderSettings copyWith({
    bool? enabled,
    int? startHour,
    int? startMinute,
    int? leadMinutes,
  }) {
    return SchoolReminderSettings(
      enabled: enabled ?? this.enabled,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      leadMinutes: leadMinutes ?? this.leadMinutes,
    );
  }

  factory SchoolReminderSettings.fromJson(Map<String, dynamic> json) {
    return SchoolReminderSettings(
      enabled: json['enabled'] as bool? ?? false,
      startHour: json['startHour'] as int? ?? 7,
      startMinute: json['startMinute'] as int? ?? 0,
      leadMinutes: json['leadMinutes'] as int? ?? 60,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'startHour': startHour,
    'startMinute': startMinute,
    'leadMinutes': leadMinutes,
  };
}

class GeneralReminder {
  final String id;
  final String title;
  final String note;
  final int hour;
  final int minute;
  final bool enabled;
  final String lastCompletedDate;

  const GeneralReminder({
    required this.id,
    required this.title,
    this.note = '',
    this.hour = 7,
    this.minute = 0,
    this.enabled = true,
    this.lastCompletedDate = '',
  });

  int get minutesOfDay => hour * 60 + minute;

  GeneralReminder copyWith({
    String? title,
    String? note,
    int? hour,
    int? minute,
    bool? enabled,
    String? lastCompletedDate,
  }) {
    return GeneralReminder(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
    );
  }

  factory GeneralReminder.fromJson(Map<String, dynamic> json) {
    return GeneralReminder(
      id: json['id'] as String,
      title: json['title'] as String,
      note: json['note'] as String? ?? '',
      hour: json['hour'] as int? ?? 7,
      minute: json['minute'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      lastCompletedDate: json['lastCompletedDate'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'hour': hour,
    'minute': minute,
    'enabled': enabled,
    'lastCompletedDate': lastCompletedDate,
  };
}

class SchoolChecklistPrompt {
  final SchoolReminderSettings settings;
  final int uncheckedItems;

  const SchoolChecklistPrompt({
    required this.settings,
    required this.uncheckedItems,
  });
}

class ReminderStore {
  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  static Future<SchoolReminderSettings> loadSchoolSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSchoolReminderSettingsKey);
    if (raw == null || raw.isEmpty) return const SchoolReminderSettings();

    try {
      return SchoolReminderSettings.fromJson(
        json.decode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const SchoolReminderSettings();
    }
  }

  static Future<void> saveSchoolSettings(
    SchoolReminderSettings settings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kSchoolReminderSettingsKey,
      json.encode(settings.toJson()),
    );
  }

  static Future<List<GeneralReminder>> loadGeneralReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kGeneralRemindersKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = json.decode(raw) as List;
      return decoded
          .map(
            (entry) => GeneralReminder.fromJson(entry as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveGeneralReminders(
    List<GeneralReminder> reminders,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(reminders.map((item) => item.toJson()).toList());
    await prefs.setString(_kGeneralRemindersKey, raw);
  }

  static Future<SchoolChecklistPrompt?> schoolChecklistPrompt({
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final settings = await loadSchoolSettings();
    if (!settings.enabled) return null;

    final currentMinutes = current.hour * 60 + current.minute;
    final start = settings.startMinutesOfDay;
    final reminderStart = start - settings.leadMinutes;
    final insideReminderWindow =
        currentMinutes >= reminderStart && currentMinutes <= start;
    if (!insideReminderWindow) return null;

    final dayKey = ChecklistStore.dayKeyForDate(current);
    final items = await ChecklistStore.itemsForDay(dayKey);
    final unchecked = items.where((item) => !item.isPacked).length;
    if (unchecked == 0) return null;

    return SchoolChecklistPrompt(settings: settings, uncheckedItems: unchecked);
  }

  static Future<List<GeneralReminder>> dueGeneralReminders({
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final today = dateKey(current);
    final currentMinutes = current.hour * 60 + current.minute;
    final reminders = await loadGeneralReminders();

    return reminders.where((reminder) {
      if (!reminder.enabled) return false;
      if (reminder.lastCompletedDate == today) return false;
      final due = reminder.minutesOfDay;
      return currentMinutes >= due && currentMinutes <= due + 90;
    }).toList();
  }

  static Future<void> completeGeneralReminder(String reminderId) async {
    final reminders = await loadGeneralReminders();
    final today = dateKey(DateTime.now());
    final updated = reminders
        .map(
          (reminder) => reminder.id == reminderId
              ? reminder.copyWith(lastCompletedDate: today)
              : reminder,
        )
        .toList();
    await saveGeneralReminders(updated);
  }

  static String dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

String formatReminderTime(int hour, int minute) {
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayMinute = minute.toString().padLeft(2, '0');
  return '$displayHour:$displayMinute $suffix';
}
