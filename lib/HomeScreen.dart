import 'package:backpackhelp/Profilepage.dart';
import 'package:backpackhelp/checklist_store.dart';
import 'package:backpackhelp/constants.dart';
import 'package:backpackhelp/reminder_store.dart';
import 'package:flutter/material.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  ChecklistSummary _summary = const ChecklistSummary(
    lists: 0,
    totalItems: 0,
    packedItems: 0,
  );
  bool _loadingSummary = true;
  SchoolChecklistPrompt? _schoolPrompt;
  List<GeneralReminder> _dueReminders = [];

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _loadReminderPrompts();
  }

  Future<void> _loadSummary() async {
    final summary = await ChecklistStore.summary();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loadingSummary = false;
    });
  }

  Future<void> _loadReminderPrompts() async {
    final schoolPrompt = await ReminderStore.schoolChecklistPrompt();
    final dueReminders = await ReminderStore.dueGeneralReminders();
    if (!mounted) return;
    setState(() {
      _schoolPrompt = schoolPrompt;
      _dueReminders = dueReminders;
    });
  }

  Future<void> _openChecklist() async {
    await Navigator.pushNamed(context, '/checklist');
    if (mounted) {
      _loadSummary();
      _loadReminderPrompts();
    }
  }

  Future<void> _openReminders() async {
    await Navigator.pushNamed(context, '/reminders');
    if (mounted) _loadReminderPrompts();
  }

  Future<void> _completeGeneralReminder(GeneralReminder reminder) async {
    await ReminderStore.completeGeneralReminder(reminder.id);
    if (mounted) _loadReminderPrompts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Backpack"),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_connected, size: 22),
            color: AppColors.teal,
            onPressed: () => Navigator.pushNamed(context, '/connection'),
            tooltip: 'Connection',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Profilepage()),
                );
              },
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceSoft,
                child: Icon(
                  Icons.person_outline,
                  size: 18,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 104),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _PageHeader(),
            const SizedBox(height: 18),
            if (_schoolPrompt != null) ...[
              _SchoolPromptCard(
                prompt: _schoolPrompt!,
                onOpenChecklist: _openChecklist,
              ),
              const SizedBox(height: 12),
            ],
            if (_dueReminders.isNotEmpty) ...[
              _DueRemindersCard(
                reminders: _dueReminders,
                onDone: _completeGeneralReminder,
                onOpenReminders: _openReminders,
              ),
              const SizedBox(height: 12),
            ],
            _BackpackHero(summary: _summary, loading: _loadingSummary),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.today_outlined,
                    label: "Lists",
                    value: _loadingSummary ? "--" : "${_summary.lists}",
                    accent: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.playlist_add_check,
                    label: "Items left",
                    value: _loadingSummary
                        ? "--"
                        : "${_summary.remainingItems}",
                    accent: AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _SectionTitle("Quick Actions"),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.playlist_add_check,
              title: "Edit packing lists",
              subtitle: "Customize Everyday and weekday items",
              color: AppColors.coral,
              onTap: _openChecklist,
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.notifications_active_outlined,
              title: "Set reminders",
              subtitle: "School start time and general reminders",
              color: AppColors.amber,
              onTap: _openReminders,
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.sensors,
              title: "Scan backpack",
              subtitle: "Refresh books, supplies, and weight",
              color: AppColors.primary,
              onTap: () => Navigator.pushNamed(context, '/scan'),
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.settings_input_antenna,
              title: "Connect reader",
              subtitle: "Set up the Raspberry Pi RFID service",
              color: AppColors.teal,
              onTap: () => Navigator.pushNamed(context, '/connection'),
            ),
            const SizedBox(height: 18),
            const _SectionTitle("Today's Focus"),
            const SizedBox(height: 10),
            _FocusCard(summary: _summary, loading: _loadingSummary),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Ready for class?",
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Your backpack essentials are summarized below.",
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.notifications_none,
            color: AppColors.ink,
            size: 22,
          ),
        ),
      ],
    );
  }
}

class _BackpackHero extends StatelessWidget {
  final ChecklistSummary summary;
  final bool loading;

  const _BackpackHero({required this.summary, required this.loading});

  @override
  Widget build(BuildContext context) {
    final heroValue = loading
        ? "Loading"
        : summary.hasItems
        ? "${summary.remainingItems} left"
        : "No list yet";
    final heroLabel = summary.hasItems
        ? "${summary.packedItems} of ${summary.totalItems} items packed"
        : "Create a checklist to start tracking items";
    final statusText = summary.hasItems
        ? summary.remainingItems == 0
              ? "All packed"
              : "Checklist active"
        : "Setup needed";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        gradient: const LinearGradient(
          colors: [AppColors.ink, AppColors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  heroValue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  heroLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.white.withValues(alpha: 0.78),
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      summary.hasItems
                          ? "Open Checklist to update items"
                          : "Add daily supplies",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            height: 132,
            child: Image.asset(
              "Assets/Backpack.png",
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.backpack,
                color: Colors.white.withValues(alpha: 0.84),
                size: 82,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SchoolPromptCard extends StatelessWidget {
  final SchoolChecklistPrompt prompt;
  final VoidCallback onOpenChecklist;

  const _SchoolPromptCard({
    required this.prompt,
    required this.onOpenChecklist,
  });

  @override
  Widget build(BuildContext context) {
    final time = formatReminderTime(
      prompt.settings.startHour,
      prompt.settings.startMinute,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: const Icon(
              Icons.school_outlined,
              color: AppColors.amber,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "School starts at $time",
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "You still have ${prompt.uncheckedItems} checklist item${prompt.uncheckedItems == 1 ? '' : 's'} unchecked.",
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onOpenChecklist, child: const Text("Check")),
        ],
      ),
    );
  }
}

class _DueRemindersCard extends StatelessWidget {
  final List<GeneralReminder> reminders;
  final ValueChanged<GeneralReminder> onDone;
  final VoidCallback onOpenReminders;

  const _DueRemindersCard({
    required this.reminders,
    required this.onDone,
    required this.onOpenReminders,
  });

  @override
  Widget build(BuildContext context) {
    final first = reminders.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  first.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatReminderTime(first.hour, first.minute),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (first.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              first.note,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenReminders,
                  child: Text(
                    reminders.length == 1
                        ? "View reminders"
                        : "View ${reminders.length} reminders",
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => onDone(first),
                  child: const Text("Done"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
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
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  final ChecklistSummary summary;
  final bool loading;

  const _FocusCard({required this.summary, required this.loading});

  @override
  Widget build(BuildContext context) {
    final focusTitle = loading
        ? "Loading checklist"
        : !summary.hasItems
        ? "Create your first packing list"
        : summary.remainingItems == 0
        ? "Everything is packed"
        : "Pack before leaving";
    final focusSubtitle = loading
        ? "Checking saved class items"
        : !summary.hasItems
        ? "Add Everyday items or customize certain days"
        : summary.remainingItems == 0
        ? "${summary.totalItems} items ready to go"
        : "${summary.remainingItems} item${summary.remainingItems == 1 ? '' : 's'} still unpacked";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _FocusRow(
            icon: Icons.assignment_turned_in_outlined,
            title: focusTitle,
            subtitle: focusSubtitle,
            color: AppColors.coral,
          ),
          const SizedBox(height: 12),
          const _FocusRow(
            icon: Icons.calendar_today_outlined,
            title: "Daily lists",
            subtitle: "Everyday items combine with each weekday",
            color: AppColors.teal,
          ),
        ],
      ),
    );
  }
}

class _FocusRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _FocusRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Shared widget used across screens
class Titleinfo extends StatelessWidget {
  final String title;
  final String subtext;
  final Widget trailing;

  const Titleinfo({
    super.key,
    required this.title,
    required this.subtext,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtext,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
