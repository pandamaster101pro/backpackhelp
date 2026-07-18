import 'package:backpackhelp/constants.dart';
import 'package:backpackhelp/notification_service.dart';
import 'package:backpackhelp/reminder_store.dart';
import 'package:flutter/material.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  SchoolReminderSettings _schoolSettings = const SchoolReminderSettings();
  List<GeneralReminder> _reminders = [];
  bool _loading = true;
  bool _showReminderEditor = false;
  GeneralReminder? _editingReminder;

  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  int _reminderHour = 7;
  int _reminderMinute = 0;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    final settings = await ReminderStore.loadSchoolSettings();
    final reminders = await ReminderStore.loadGeneralReminders();
    if (!mounted) return;
    setState(() {
      _schoolSettings = settings;
      _reminders = reminders;
      _loading = false;
    });
  }

  Future<void> _saveSchoolSettings(SchoolReminderSettings settings) async {
    setState(() => _schoolSettings = settings);
    await ReminderStore.saveSchoolSettings(settings);
    await NotificationService.scheduleAll(requestPermissions: true);
  }

  Future<void> _saveReminders(List<GeneralReminder> reminders) async {
    setState(() => _reminders = reminders);
    await ReminderStore.saveGeneralReminders(reminders);
    await NotificationService.scheduleAll(requestPermissions: true);
  }

  void _startAddingReminder() {
    setState(() {
      _editingReminder = null;
      _titleController.clear();
      _noteController.clear();
      _reminderHour = 7;
      _reminderMinute = 0;
      _showReminderEditor = true;
    });
  }

  void _startEditingReminder(GeneralReminder reminder) {
    setState(() {
      _editingReminder = reminder;
      _titleController.text = reminder.title;
      _noteController.text = reminder.note;
      _reminderHour = reminder.hour;
      _reminderMinute = reminder.minute;
      _showReminderEditor = true;
    });
  }

  void _cancelEditingReminder() {
    setState(() {
      _editingReminder = null;
      _titleController.clear();
      _noteController.clear();
      _showReminderEditor = false;
    });
  }

  Future<void> _saveReminderFromEditor() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final note = _noteController.text.trim();
    final editing = _editingReminder;

    final updated = editing == null
        ? [
            ..._reminders,
            GeneralReminder(
              id: ReminderStore.newId(),
              title: title,
              note: note,
              hour: _reminderHour,
              minute: _reminderMinute,
            ),
          ]
        : _reminders
              .map(
                (reminder) => reminder.id == editing.id
                    ? reminder.copyWith(
                        title: title,
                        note: note,
                        hour: _reminderHour,
                        minute: _reminderMinute,
                      )
                    : reminder,
              )
              .toList();

    await _saveReminders(updated);
    _cancelEditingReminder();
  }

  Future<void> _toggleReminder(GeneralReminder reminder) async {
    final updated = _reminders
        .map(
          (item) => item.id == reminder.id
              ? item.copyWith(enabled: !item.enabled)
              : item,
        )
        .toList();
    await _saveReminders(updated);
  }

  Future<void> _deleteReminder(GeneralReminder reminder) async {
    if (_editingReminder?.id == reminder.id) _cancelEditingReminder();
    final updated = _reminders.where((item) => item.id != reminder.id).toList();
    await _saveReminders(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Reminders"),
        actions: [
          IconButton(
            onPressed: _loading ? null : _startAddingReminder,
            icon: const Icon(Icons.add_alert_outlined),
            tooltip: "Add reminder",
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Reminder Center",
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Set your school start time and quick daily reminders.",
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  _SchoolReminderCard(
                    settings: _schoolSettings,
                    onChanged: _saveSchoolSettings,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "General Reminders",
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _startAddingReminder,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Add"),
                      ),
                    ],
                  ),
                  if (_showReminderEditor) ...[
                    _ReminderEditor(
                      editing: _editingReminder != null,
                      titleController: _titleController,
                      noteController: _noteController,
                      hour: _reminderHour,
                      minute: _reminderMinute,
                      onHourChanged: (value) =>
                          setState(() => _reminderHour = value),
                      onMinuteChanged: (value) =>
                          setState(() => _reminderMinute = value),
                      onCancel: _cancelEditingReminder,
                      onSave: _saveReminderFromEditor,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_reminders.isEmpty)
                    _EmptyReminderCard(onAdd: _startAddingReminder)
                  else
                    _ReminderList(
                      reminders: _reminders,
                      onToggle: _toggleReminder,
                      onEdit: _startEditingReminder,
                      onDelete: _deleteReminder,
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _startAddingReminder,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text("Reminder"),
      ),
    );
  }
}

class _SchoolReminderCard extends StatelessWidget {
  final SchoolReminderSettings settings;
  final ValueChanged<SchoolReminderSettings> onChanged;

  const _SchoolReminderCard({required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "School checklist reminder",
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Show a prompt before school if items are unchecked.",
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.enabled,
                activeThumbColor: AppColors.primary,
                onChanged: (value) =>
                    onChanged(settings.copyWith(enabled: value)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _NumberDropdown(
                  label: "Hour",
                  value: settings.startHour,
                  values: List.generate(24, (index) => index),
                  formatter: (value) =>
                      formatReminderTime(value, 0).replaceFirst(':00', ''),
                  onChanged: (value) =>
                      onChanged(settings.copyWith(startHour: value)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberDropdown(
                  label: "Minute",
                  value: settings.startMinute,
                  values: const [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55],
                  formatter: (value) => value.toString().padLeft(2, '0'),
                  onChanged: (value) =>
                      onChanged(settings.copyWith(startMinute: value)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Remind me before school",
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [15, 30, 45, 60, 90].map((minutes) {
              final selected = settings.leadMinutes == minutes;
              return ChoiceChip(
                selected: selected,
                onSelected: (_) =>
                    onChanged(settings.copyWith(leadMinutes: minutes)),
                label: Text("$minutes min"),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
                side: const BorderSide(color: AppColors.border),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ReminderEditor extends StatelessWidget {
  final bool editing;
  final TextEditingController titleController;
  final TextEditingController noteController;
  final int hour;
  final int minute;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _ReminderEditor({
    required this.editing,
    required this.titleController,
    required this.noteController,
    required this.hour,
    required this.minute,
    required this.onHourChanged,
    required this.onMinuteChanged,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            editing ? "Edit reminder" : "Add reminder",
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: "Reminder",
              hintText: "Charge Chromebook, bring lunch...",
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: "Note",
              hintText: "Optional details",
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _NumberDropdown(
                  label: "Hour",
                  value: hour,
                  values: List.generate(24, (index) => index),
                  formatter: (value) =>
                      formatReminderTime(value, 0).replaceFirst(':00', ''),
                  onChanged: onHourChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _NumberDropdown(
                  label: "Minute",
                  value: minute,
                  values: const [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55],
                  formatter: (value) => value.toString().padLeft(2, '0'),
                  onChanged: onMinuteChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text("Cancel"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onSave,
                  child: Text(editing ? "Save reminder" : "Add reminder"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberDropdown extends StatelessWidget {
  final String label;
  final int value;
  final List<int> values;
  final String Function(int) formatter;
  final ValueChanged<int> onChanged;

  const _NumberDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.formatter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: values
          .map(
            (item) => DropdownMenuItem<int>(
              value: item,
              child: Text(formatter(item)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _EmptyReminderCard extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyReminderCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: AppColors.primary,
            size: 34,
          ),
          const SizedBox(height: 12),
          const Text(
            "No general reminders yet",
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Add reminders for anything you want the app to surface later.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text("Add reminder"),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderList extends StatelessWidget {
  final List<GeneralReminder> reminders;
  final ValueChanged<GeneralReminder> onToggle;
  final ValueChanged<GeneralReminder> onEdit;
  final ValueChanged<GeneralReminder> onDelete;

  const _ReminderList({
    required this.reminders,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...reminders]
      ..sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(sorted.length, (index) {
          final reminder = sorted[index];
          return Column(
            children: [
              ListTile(
                leading: Switch(
                  value: reminder.enabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (_) => onToggle(reminder),
                ),
                title: Text(
                  reminder.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  [
                    formatReminderTime(reminder.hour, reminder.minute),
                    if (reminder.note.isNotEmpty) reminder.note,
                  ].join(' - '),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                trailing: Wrap(
                  spacing: 2,
                  children: [
                    IconButton(
                      onPressed: () => onEdit(reminder),
                      icon: const Icon(Icons.edit_outlined, size: 19),
                      color: AppColors.muted,
                      tooltip: "Edit reminder",
                    ),
                    IconButton(
                      onPressed: () => onDelete(reminder),
                      icon: const Icon(Icons.delete_outline, size: 19),
                      color: AppColors.danger,
                      tooltip: "Delete reminder",
                    ),
                  ],
                ),
              ),
              if (index < sorted.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF0F0EE),
                ),
            ],
          );
        }),
      ),
    );
  }
}
