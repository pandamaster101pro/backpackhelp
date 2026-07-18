import 'package:backpackhelp/checklist_store.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// key used to persist the calendar URL between sessions
const _kIcalKey = 'ical_url';

class CalEvent {
  final String title;
  final DateTime date;
  final String? rawCourse;
  final String? courseName;

  CalEvent({
    required this.title,
    required this.date,
    this.rawCourse,
    this.courseName,
  });
}

List<CalEvent> _parseIcal(String raw) {
  // iCal allows long lines to be split with a leading space/tab on the next line — join them back
  final unfolded = raw
      .replaceAll(RegExp(r'\r\n[ \t]'), '')
      .replaceAll(RegExp(r'\n[ \t]'), '');
  final lines = unfolded.split(RegExp(r'\r?\n'));
  final events = <CalEvent>[];
  Map<String, String> current = {};
  bool inEvent = false;

  for (final line in lines) {
    if (line.trim() == 'BEGIN:VEVENT') {
      inEvent = true;
      current = {};
    } else if (line.trim() == 'END:VEVENT') {
      inEvent = false;
      final e = _buildEvent(current);
      if (e != null) events.add(e);
    } else if (inEvent) {
      // properties look like "DTSTART;TZID=...:value" — drop semicolon params from the key
      final colon = line.indexOf(':');
      if (colon == -1) continue;
      final key = line.substring(0, colon).split(';').first.toUpperCase();
      current[key] = line.substring(colon + 1);
    }
  }

  events.sort((a, b) => a.date.compareTo(b.date));
  return events;
}

CalEvent? _buildEvent(Map<String, String> props) {
  final rawSummary = props['SUMMARY'] ?? '';
  final rawDate = props['DTSTART'] ?? '';
  if (rawDate.isEmpty) return null;

  DateTime? date;
  try {
    // strip everything except digits to handle both date-only and datetime formats
    final digits = rawDate.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 8) {
      final y = int.parse(digits.substring(0, 4));
      final m = int.parse(digits.substring(4, 6));
      final d = int.parse(digits.substring(6, 8));
      int h = 0, min = 0;
      if (digits.length >= 12) {
        h = int.parse(digits.substring(8, 10));
        min = int.parse(digits.substring(10, 12));
      }
      date = DateTime(y, m, d, h, min);
    }
  } catch (_) {
    return null;
  }
  if (date == null) return null;

  String title = rawSummary.replaceAll(r'\n', ' ').trim();
  String? rawCourse;
  String? courseName;

  // Canvas appends the course name in square brackets at the end of every event title
  final bracketMatch = RegExp(r'\[([^\]]+)\]$').firstMatch(title);
  if (bracketMatch != null) {
    rawCourse = bracketMatch.group(1)!.trim();
    title = title.substring(0, bracketMatch.start).trim();
    courseName = _cleanCourseName(rawCourse);
  }

  return CalEvent(
    title: title,
    date: date,
    rawCourse: rawCourse,
    courseName: courseName,
  );
}

/// Strips teacher names and year suffixes from a Canvas course string.
String _cleanCourseName(String raw) {
  String s = raw;

  s = s.replaceAll(RegExp(r',\s*\w+\s*$'), '');
  s = s.replaceAll(RegExp(r'\s+\w+,\s*\w+\s*$'), '');
  s = s.replaceAll(RegExp(r'\b\d{2,4}-\d{2,4}\b'), '');
  s = _stripLeadingTeacherName(s.trim());
  s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

  // fall back to the original if cleaning produced an empty string
  return s.isEmpty ? raw : s;
}

/// Removes leading words that look like a teacher name (Title Case, not a known course-word).
String _stripLeadingTeacherName(String s) {
  const courseStarters = {
    'ap',
    'ib',
    'honors',
    'advanced',
    'intro',
    'introduction',
    'survey',
    'english',
    'math',
    'science',
    'history',
    'art',
    'music',
    'pe',
    'physics',
    'chemistry',
    'biology',
    'calculus',
    'algebra',
    'geometry',
    'statistics',
    'economics',
    'psychology',
    'sociology',
    'philosophy',
    'computer',
    'engineering',
    'robotics',
    'drama',
    'theater',
    'spanish',
    'french',
    'chinese',
    'mandarin',
    'japanese',
    'latin',
    'grade',
    'level',
    'hpc',
    'modern',
    'world',
    'us',
    'american',
    'global',
    'environmental',
    'pre',
    'precalc',
  };

  final words = s.split(' ');
  int stripCount = 0;
  for (int i = 0; i < words.length && i < 2; i++) {
    final w = words[i];
    if (w.isEmpty) continue;
    final isTitle = w[0] == w[0].toUpperCase() && w[0] != w[0].toLowerCase();
    final isKnownCourse = courseStarters.contains(w.toLowerCase());
    if (isTitle && !isKnownCourse && RegExp(r'^[A-Z][a-z]+$').hasMatch(w)) {
      stripCount = i + 1;
    } else {
      break;
    }
  }

  if (stripCount > 0 && stripCount < words.length) {
    return words.sublist(stripCount).join(' ').trim();
  }
  return s;
}

// same course name always produces the same color via hash
const _palette = [
  Color(0xFF5B8AF0),
  Color(0xFF57C4A0),
  Color(0xFFE07B5A),
  Color(0xFFB07FD4),
  Color(0xFF5EC4C4),
  Color(0xFFE8A838),
  Color(0xFFE05A8A),
  Color(0xFF7DBD6F),
  Color(0xFF7B9FE0),
  Color(0xFFD4855A),
  Color(0xFF6BA5D4),
  Color(0xFFC47DB0),
];

Color _courseColor(String course) =>
    _palette[course.toLowerCase().hashCode.abs() % _palette.length];

String _formatTime(DateTime d) {
  if (d.hour == 0 && d.minute == 0) return 'All day';
  final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

class _SchedulePackItem {
  final String listLabel;
  final String itemId;
  final String itemName;
  final String note;

  const _SchedulePackItem({
    required this.listLabel,
    required this.itemId,
    required this.itemName,
    required this.note,
  });
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class Schedule extends StatefulWidget {
  const Schedule({super.key});
  @override
  State<Schedule> createState() => _ScheduleState();
}

class _ScheduleState extends State<Schedule> {
  String? _icalUrl;
  List<CalEvent> _allEvents = [];
  List<DayChecklist> _dayChecklists = [];
  bool _loading = false;
  String? _error;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedDay;
  // keyed by "year-month-day-courseName" so state is isolated per day
  final Map<String, bool> _packed = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now().day;
    _loadSavedUrl();
    _loadChecklists();
  }

  // restore saved URL on launch and immediately fetch
  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kIcalKey);
    if (saved != null && saved.isNotEmpty) {
      setState(() => _icalUrl = saved);
      _fetch(saved);
    }
  }

  Future<void> _loadChecklists() async {
    final checklists = await ChecklistStore.load();
    if (!mounted) return;
    setState(() => _dayChecklists = checklists);
  }

  Future<void> _saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kIcalKey, url);
  }

  Future<void> _clearUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIcalKey);
    setState(() {
      _icalUrl = null;
      _allEvents = [];
      _error = null;
    });
  }

  Future<void> _fetch(String url) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse(url.trim()))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      // quick check that the response is actually an iCal file
      if (!res.body.contains('BEGIN:VCALENDAR')) {
        throw Exception('not_ical');
      }
      final events = _parseIcal(res.body);
      // guard against setState being called after the widget is disposed
      if (mounted)
        setState(() {
          _allEvents = events;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString().contains('not_ical')
              ? "That URL doesn't look like a valid iCal feed"
              : 'Failed to load calendar. Check the URL and try again.';
          _loading = false;
        });
    }
  }

  void _showUrlSheet() {
    final controller = TextEditingController(text: _icalUrl ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        // shift sheet above keyboard when it appears
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Calendar Feed URL',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Paste your iCal (.ics) link.\nCanvas: Calendar → Calendar Feed (bottom right).',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black45,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              decoration: InputDecoration(
                hintText:
                    'https://yourschool.instructure.com/feeds/calendars/...',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.black26),
                filled: true,
                fillColor: const Color(0xFFF7F7F5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black26),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_icalUrl != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _clearUrl();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Remove',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final url = controller.text.trim();
                      if (url.isEmpty) return;
                      Navigator.pop(ctx);
                      setState(() => _icalUrl = url);
                      _saveUrl(url);
                      _fetch(url);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Save & Load',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  //  Data helpers

  List<CalEvent> get _monthEvents => _allEvents
      .where(
        (e) =>
            e.date.year == _focusedMonth.year &&
            e.date.month == _focusedMonth.month,
      )
      .toList();

  List<CalEvent> get _dayEvents {
    if (_selectedDay == null) return [];
    return _monthEvents.where((e) => e.date.day == _selectedDay).toList();
  }

  Set<int> get _daysWithEvents => _monthEvents.map((e) => e.date.day).toSet();

  List<_SchedulePackItem> get _todayChecklistItems {
    if (_selectedDay == null || _dayChecklists.isEmpty) return [];
    final selectedDate = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      _selectedDay!,
    );
    final selectedKey = ChecklistStore.dayKeyForDate(selectedDate);
    final result = <_SchedulePackItem>[];

    for (final list in _dayChecklists) {
      final shouldInclude =
          list.dayKey == 'everyday' || list.dayKey == selectedKey;
      if (!shouldInclude) continue;

      for (final item in list.items) {
        result.add(
          _SchedulePackItem(
            listLabel: list.label,
            itemId: item.id,
            itemName: item.name,
            note: item.note,
          ),
        );
      }
    }
    return result;
  }

  void _prevMonth() => setState(() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    _selectedDay = null;
  });

  void _nextMonth() => setState(() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    _selectedDay = null;
  });

  String _packedKey(String course) =>
      '${_focusedMonth.year}-${_focusedMonth.month}-$_selectedDay-$course';

  // Build

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isCurrentMonth =
        _focusedMonth.year == today.year && _focusedMonth.month == today.month;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        title: const Text(
          'Schedule',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF7F7F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (_icalUrl != null && !_loading)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              color: Colors.black45,
              onPressed: () => _fetch(_icalUrl!),
            ),
          IconButton(
            icon: const Icon(Icons.link, size: 20),
            color: Colors.black45,
            onPressed: _showUrlSheet,
            tooltip: 'Set calendar URL',
          ),
        ],
      ),
      body: _icalUrl == null
          ? _buildSetupPrompt()
          : _loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.black45,
              ),
            )
          : _error != null
          ? _ErrorState(
              message: _error!,
              onRetry: () => _fetch(_icalUrl!),
              onChangeUrl: _showUrlSheet,
            )
          : _buildBody(today, isCurrentMonth),
    );
  }

  Widget _buildSetupPrompt() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              size: 28,
              color: Colors.black38,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Connect your calendar',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Paste your iCal feed URL to load your schedule. Your selected day will show Everyday items plus that weekday list.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black45, height: 1.6),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showUrlSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Add Calendar URL',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Canvas: Calendar → Calendar Feed\nGoogle: Settings → Export calendar',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black38, height: 1.7),
          ),
        ],
      ),
    ),
  );

  Widget _buildBody(DateTime today, bool isCurrentMonth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Schedule",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a day to see events and what to pack',
            style: TextStyle(fontSize: 14, color: Colors.black45),
          ),
          const SizedBox(height: 24),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '${_monthLong[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    _NavBtn(icon: Icons.chevron_left, onTap: _prevMonth),
                    const SizedBox(width: 4),
                    _NavBtn(icon: Icons.chevron_right, onTap: _nextMonth),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .map(
                        (d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black38,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 6),
                _buildGrid(today, isCurrentMonth),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _SectionLabel(
            text: _selectedDay != null
                ? '${_weekdays[DateTime(_focusedMonth.year, _focusedMonth.month, _selectedDay!).weekday - 1]}, ${_monthShort[_focusedMonth.month - 1]} $_selectedDay'
                : 'Events',
            count: _dayEvents.isNotEmpty ? '${_dayEvents.length}' : null,
          ),
          const SizedBox(height: 10),

          _dayEvents.isEmpty
              ? const _EmptyCard(
                  icon: Icons.event_available_outlined,
                  label: 'No events',
                )
              : _WhiteCard(
                  children: List.generate(
                    _dayEvents.length,
                    (i) => _DayEventTile(
                      event: _dayEvents[i],
                      isLast: i == _dayEvents.length - 1,
                    ),
                  ),
                ),

          const SizedBox(height: 24),

          const _SectionLabel(text: 'Packing List'),
          const SizedBox(height: 10),

          _selectedDay == null
              ? const _EmptyCard(
                  icon: Icons.check_circle_outline,
                  label: 'Select a day to see what to bring',
                )
              : _todayChecklistItems.isEmpty
              ? const _EmptyCard(
                  icon: Icons.playlist_add_check,
                  label: 'No checklist items for this day yet',
                )
              : _WhiteCard(
                  children: List.generate(_todayChecklistItems.length, (i) {
                    final item = _todayChecklistItems[i];
                    final key = _packedKey('${item.listLabel}-${item.itemId}');
                    final checked = _packed[key] ?? false;
                    return _PackedItemTile(
                      item: item,
                      checked: checked,
                      isLast: i == _todayChecklistItems.length - 1,
                      onTap: () => setState(() => _packed[key] = !checked),
                    );
                  }),
                ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildGrid(DateTime today, bool isCurrentMonth) {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    // Flutter weekday is 1=Mon...7=Sun, mod 7 converts it to a Sunday-based offset
    final startOffset = firstDay.weekday % 7;
    final daysWithEvents = _daysWithEvents;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: startOffset + daysInMonth,
      itemBuilder: (_, i) {
        if (i < startOffset) return const SizedBox();
        final day = i - startOffset + 1;
        final isToday = isCurrentMonth && today.day == day;
        final isSelected = _selectedDay == day;
        final hasEvents = daysWithEvents.contains(day);

        return GestureDetector(
          onTap: () => setState(() => _selectedDay = day),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.black87
                        : isToday
                        ? Colors.black.withOpacity(0.08)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday || isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
                if (hasEvents && !isSelected)
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

//  Reusable widgets

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, size: 16, color: Colors.black54),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final String? count;
  const _SectionLabel({required this.text, this.count});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black45,
          letterSpacing: 0.5,
        ),
      ),
      if (count != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count!,
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ),
      ],
    ],
  );
}

class _WhiteCard extends StatelessWidget {
  final List<Widget> children;
  const _WhiteCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black.withOpacity(0.06)),
    ),
    child: Column(children: children),
  );
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyCard({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black.withOpacity(0.06)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 28, color: Colors.black26),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black38),
        ),
      ],
    ),
  );
}

class _DayEventTile extends StatelessWidget {
  final CalEvent event;
  final bool isLast;
  const _DayEventTile({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = event.courseName != null
        ? _courseColor(event.courseName!)
        : Colors.black26;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 54,
                child: Text(
                  _formatTime(event.date),
                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 3, right: 10),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    if (event.courseName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        event.courseName!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black38,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0EE)),
      ],
    );
  }
}

class _PackedItemTile extends StatelessWidget {
  final _SchedulePackItem item;
  final bool checked;
  final bool isLast;
  final VoidCallback onTap;
  const _PackedItemTile({
    required this.item,
    required this.checked,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _courseColor(item.listLabel);
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          // only round the bottom corners on the last item to match the card shape
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: checked ? Colors.black87 : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: checked ? Colors.black87 : Colors.black26,
                      width: 1.5,
                    ),
                  ),
                  child: checked
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.menu_book_outlined, size: 15, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: checked ? Colors.black38 : Colors.black87,
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.note.isEmpty
                            ? item.listLabel
                            : '${item.listLabel} - ${item.note}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black38,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0EE)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onChangeUrl;
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.onChangeUrl,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_outlined, color: Colors.black26, size: 36),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black45,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: onChangeUrl,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.black26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Change URL', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.black26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// kept for backwards compatibility
class SubjectBar extends StatelessWidget {
  final IconData icon;
  final String subjectName;
  final String time;
  final Color iconColor;
  final bool isLast;
  const SubjectBar({
    super.key,
    required this.icon,
    required this.subjectName,
    required this.time,
    required this.iconColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subjectName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 12, color: Colors.black38),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      if (!isLast)
        const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0EE)),
    ],
  );
}
