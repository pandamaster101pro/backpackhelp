import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _kDayChecklistKey = 'day_checklists';
const _kOldClassChecklistKey = 'class_checklists';

class ChecklistDay {
  final String key;
  final String label;

  const ChecklistDay({required this.key, required this.label});
}

const checklistDays = [
  ChecklistDay(key: 'everyday', label: 'Everyday'),
  ChecklistDay(key: 'monday', label: 'Monday'),
  ChecklistDay(key: 'tuesday', label: 'Tuesday'),
  ChecklistDay(key: 'wednesday', label: 'Wednesday'),
  ChecklistDay(key: 'thursday', label: 'Thursday'),
  ChecklistDay(key: 'friday', label: 'Friday'),
  ChecklistDay(key: 'saturday', label: 'Saturday'),
  ChecklistDay(key: 'sunday', label: 'Sunday'),
];

class ChecklistItem {
  final String id;
  final String name;
  final String note;
  final bool isPacked;

  const ChecklistItem({
    required this.id,
    required this.name,
    this.note = '',
    this.isPacked = false,
  });

  ChecklistItem copyWith({String? name, String? note, bool? isPacked}) {
    return ChecklistItem(
      id: id,
      name: name ?? this.name,
      note: note ?? this.note,
      isPacked: isPacked ?? this.isPacked,
    );
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      name: json['name'] as String,
      note: json['note'] as String? ?? '',
      isPacked: json['isPacked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'note': note,
    'isPacked': isPacked,
  };
}

class DayChecklist {
  final String dayKey;
  final String label;
  final List<ChecklistItem> items;

  const DayChecklist({
    required this.dayKey,
    required this.label,
    required this.items,
  });

  int get totalItems => items.length;
  int get packedItems => items.where((item) => item.isPacked).length;
  int get remainingItems => totalItems - packedItems;

  DayChecklist copyWith({List<ChecklistItem>? items}) {
    return DayChecklist(
      dayKey: dayKey,
      label: label,
      items: items ?? this.items,
    );
  }

  factory DayChecklist.fromJson(Map<String, dynamic> json) {
    final key = json['dayKey'] as String;
    return DayChecklist(
      dayKey: key,
      label: ChecklistStore.labelForDay(key),
      items: (json['items'] as List? ?? [])
          .map((item) => ChecklistItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'dayKey': dayKey,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class ChecklistSummary {
  final int lists;
  final int totalItems;
  final int packedItems;

  const ChecklistSummary({
    required this.lists,
    required this.totalItems,
    required this.packedItems,
  });

  int get remainingItems => totalItems - packedItems;
  bool get hasItems => totalItems > 0;
}

class ChecklistStore {
  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  static String labelForDay(String dayKey) {
    return checklistDays
        .firstWhere(
          (day) => day.key == dayKey,
          orElse: () => const ChecklistDay(key: 'everyday', label: 'Everyday'),
        )
        .label;
  }

  static String dayKeyForDate(DateTime date) {
    return switch (date.weekday) {
      DateTime.monday => 'monday',
      DateTime.tuesday => 'tuesday',
      DateTime.wednesday => 'wednesday',
      DateTime.thursday => 'thursday',
      DateTime.friday => 'friday',
      DateTime.saturday => 'saturday',
      DateTime.sunday => 'sunday',
      _ => 'everyday',
    };
  }

  static Future<List<DayChecklist>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDayChecklistKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw) as List;
        return _mergeWithDefaultDays(
          decoded
              .map(
                (entry) => DayChecklist.fromJson(entry as Map<String, dynamic>),
              )
              .toList(),
        );
      } catch (_) {
        return _emptyDays();
      }
    }

    final migrated = _migrateOldClassData(prefs);
    if (migrated != null) {
      await save(migrated);
      await prefs.remove(_kOldClassChecklistKey);
      return migrated;
    }

    return _emptyDays();
  }

  static Future<void> save(List<DayChecklist> days) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(days.map((entry) => entry.toJson()).toList());
    await prefs.setString(_kDayChecklistKey, raw);
  }

  static Future<ChecklistSummary> summary() async {
    final days = await load();
    final totalItems = days.fold<int>(
      0,
      (total, entry) => total + entry.totalItems,
    );
    final packedItems = days.fold<int>(
      0,
      (total, entry) => total + entry.packedItems,
    );
    final activeLists = days.where((entry) => entry.items.isNotEmpty).length;

    return ChecklistSummary(
      lists: activeLists,
      totalItems: totalItems,
      packedItems: packedItems,
    );
  }

  static Future<List<ChecklistItem>> itemsForDay(String dayKey) async {
    final days = await load();
    final everyday = days.firstWhere((day) => day.dayKey == 'everyday').items;
    final selected = days.firstWhere((day) => day.dayKey == dayKey).items;
    if (dayKey == 'everyday') return everyday;
    return [...everyday, ...selected];
  }

  static Future<void> resetPackedItems() async {
    final days = await load();
    final reset = days
        .map(
          (entry) => entry.copyWith(
            items: entry.items
                .map((item) => item.copyWith(isPacked: false))
                .toList(),
          ),
        )
        .toList();
    await save(reset);
  }

  static List<DayChecklist> _emptyDays() {
    return checklistDays
        .map(
          (day) => DayChecklist(dayKey: day.key, label: day.label, items: []),
        )
        .toList();
  }

  static List<DayChecklist> _mergeWithDefaultDays(List<DayChecklist> saved) {
    final savedByKey = {for (final day in saved) day.dayKey: day};
    return checklistDays.map((day) {
      final savedDay = savedByKey[day.key];
      return DayChecklist(
        dayKey: day.key,
        label: day.label,
        items: savedDay?.items ?? [],
      );
    }).toList();
  }

  static List<DayChecklist>? _migrateOldClassData(SharedPreferences prefs) {
    final raw = prefs.getString(_kOldClassChecklistKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = json.decode(raw) as List;
      final migratedItems = <ChecklistItem>[];
      for (final entry in decoded) {
        final data = entry as Map<String, dynamic>;
        final className = data['className'] as String? ?? '';
        for (final item in data['items'] as List? ?? []) {
          final itemData = item as Map<String, dynamic>;
          migratedItems.add(
            ChecklistItem(
              id: itemData['id'] as String? ?? newId(),
              name: itemData['name'] as String? ?? 'Item',
              note: className,
              isPacked: itemData['isPacked'] as bool? ?? false,
            ),
          );
        }
      }

      final days = _emptyDays();
      return days
          .map(
            (day) => day.dayKey == 'everyday'
                ? day.copyWith(items: migratedItems)
                : day,
          )
          .toList();
    } catch (_) {
      return null;
    }
  }
}
