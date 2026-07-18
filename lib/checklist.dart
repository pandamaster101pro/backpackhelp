import 'package:backpackhelp/checklist_store.dart';
import 'package:backpackhelp/constants.dart';
import 'package:flutter/material.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  List<DayChecklist> _days = [];
  bool _loading = true;
  int _selectedIndex = 0;
  bool _showItemEditor = false;
  ChecklistItem? _editingItem;

  final _itemNameController = TextEditingController();
  final _itemNoteController = TextEditingController();

  DayChecklist get _selectedDay => _days[_selectedIndex];
  int get _totalItems => _days.fold(0, (total, day) => total + day.totalItems);
  int get _packedItems =>
      _days.fold(0, (total, day) => total + day.packedItems);
  int get _remainingItems => _totalItems - _packedItems;

  @override
  void initState() {
    super.initState();
    _loadChecklists();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadChecklists() async {
    final days = await ChecklistStore.load();
    if (!mounted) return;
    setState(() {
      _days = days;
      _loading = false;
    });
  }

  Future<void> _saveDays(List<DayChecklist> days) async {
    setState(() => _days = days);
    await ChecklistStore.save(days);
  }

  void _startAddingItem() {
    setState(() {
      _editingItem = null;
      _itemNameController.clear();
      _itemNoteController.clear();
      _showItemEditor = true;
    });
  }

  void _startEditingItem(ChecklistItem item) {
    setState(() {
      _editingItem = item;
      _itemNameController.text = item.name;
      _itemNoteController.text = item.note;
      _showItemEditor = true;
    });
  }

  void _cancelEditingItem() {
    setState(() {
      _editingItem = null;
      _itemNameController.clear();
      _itemNoteController.clear();
      _showItemEditor = false;
    });
  }

  Future<void> _saveItemFromEditor() async {
    final name = _itemNameController.text.trim();
    if (name.isEmpty) return;
    final note = _itemNoteController.text.trim();
    final editingItem = _editingItem;

    final updatedDays = _days.map((day) {
      if (day.dayKey != _selectedDay.dayKey) return day;
      if (editingItem == null) {
        return day.copyWith(
          items: [
            ...day.items,
            ChecklistItem(id: ChecklistStore.newId(), name: name, note: note),
          ],
        );
      }

      return day.copyWith(
        items: day.items
            .map(
              (current) => current.id == editingItem.id
                  ? current.copyWith(name: name, note: note)
                  : current,
            )
            .toList(),
      );
    }).toList();
    await _saveDays(updatedDays);
    _cancelEditingItem();
  }

  Future<void> _toggleItem(ChecklistItem item) async {
    final updatedDays = _days.map((day) {
      if (day.dayKey != _selectedDay.dayKey) return day;
      return day.copyWith(
        items: day.items
            .map(
              (current) => current.id == item.id
                  ? current.copyWith(isPacked: !current.isPacked)
                  : current,
            )
            .toList(),
      );
    }).toList();
    await _saveDays(updatedDays);
  }

  Future<void> _deleteItem(ChecklistItem item) async {
    if (_editingItem?.id == item.id) {
      _cancelEditingItem();
    }
    final updatedDays = _days.map((day) {
      if (day.dayKey != _selectedDay.dayKey) return day;
      return day.copyWith(
        items: day.items.where((current) => current.id != item.id).toList(),
      );
    }).toList();
    await _saveDays(updatedDays);
  }

  Future<void> _resetPackedItems() async {
    final updatedDays = _days
        .map(
          (day) => day.copyWith(
            items: day.items
                .map((item) => item.copyWith(isPacked: false))
                .toList(),
          ),
        )
        .toList();
    await _saveDays(updatedDays);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Checklist"),
        actions: [
          IconButton(
            onPressed: _loading ? null : _startAddingItem,
            icon: const Icon(Icons.add),
            tooltip: "Add item",
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
                    "Daily Packing List",
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Use Everyday for your default list, then customize each day.",
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  _SummaryCard(
                    activeLists: _days
                        .where((day) => day.items.isNotEmpty)
                        .length,
                    totalItems: _totalItems,
                    packedItems: _packedItems,
                    remainingItems: _remainingItems,
                    onReset: _totalItems == 0 ? null : _resetPackedItems,
                  ),
                  const SizedBox(height: 16),
                  _DaySelector(
                    days: _days,
                    selectedIndex: _selectedIndex,
                    onSelected: (index) => setState(() {
                      _selectedIndex = index;
                      _showItemEditor = false;
                      _editingItem = null;
                      _itemNameController.clear();
                      _itemNoteController.clear();
                    }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedDay.label,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        "${_selectedDay.packedItems}/${_selectedDay.totalItems} packed",
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_showItemEditor) ...[
                    _InlineItemEditor(
                      dayLabel: _selectedDay.label,
                      editing: _editingItem != null,
                      nameController: _itemNameController,
                      noteController: _itemNoteController,
                      onCancel: _cancelEditingItem,
                      onSave: _saveItemFromEditor,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_selectedDay.items.isEmpty)
                    _EmptyChecklist(
                      dayLabel: _selectedDay.label,
                      onAddItem: _startAddingItem,
                    )
                  else
                    _ItemCard(
                      items: _selectedDay.items,
                      onToggle: _toggleItem,
                      onEdit: _startEditingItem,
                      onDelete: _deleteItem,
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _startAddingItem,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Item"),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int activeLists;
  final int totalItems;
  final int packedItems;
  final int remainingItems;
  final VoidCallback? onReset;

  const _SummaryCard({
    required this.activeLists,
    required this.totalItems,
    required this.packedItems,
    required this.remainingItems,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Packing progress",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onReset,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.82),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text("Reset"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SummaryPill(label: "Lists", value: "$activeLists"),
              const SizedBox(width: 8),
              _SummaryPill(label: "Packed", value: "$packedItems"),
              const SizedBox(width: 8),
              _SummaryPill(label: "Left", value: "$remainingItems"),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  final List<DayChecklist> days;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _DaySelector({
    required this.days,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          final selected = index == selectedIndex;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onSelected(index),
            label: Text(
              day.label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            avatar: day.items.isEmpty
                ? null
                : CircleAvatar(
                    radius: 10,
                    backgroundColor: selected
                        ? Colors.white.withValues(alpha: 0.18)
                        : AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      "${day.items.length}",
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
          );
        },
      ),
    );
  }
}

class _InlineItemEditor extends StatelessWidget {
  final String dayLabel;
  final bool editing;
  final TextEditingController nameController;
  final TextEditingController noteController;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _InlineItemEditor({
    required this.dayLabel,
    required this.editing,
    required this.nameController,
    required this.noteController,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            editing ? "Edit item" : "Add item for $dayLabel",
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: "Item",
              hintText: "Notebook, laptop, gym clothes...",
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: "Class or note",
              hintText: "Math, science lab, bring only on test days...",
            ),
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
                  child: Text(editing ? "Save item" : "Add item"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyChecklist extends StatelessWidget {
  final String dayLabel;
  final VoidCallback onAddItem;

  const _EmptyChecklist({required this.dayLabel, required this.onAddItem});

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
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: const Icon(
              Icons.playlist_add_check,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "No $dayLabel items yet",
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Add what you need to bring and include a class note when helpful.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAddItem,
              icon: const Icon(Icons.add),
              label: const Text("Add item"),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final List<ChecklistItem> items;
  final ValueChanged<ChecklistItem> onToggle;
  final ValueChanged<ChecklistItem> onEdit;
  final ValueChanged<ChecklistItem> onDelete;

  const _ItemCard({
    required this.items,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Column(
            children: [
              _ChecklistItemTile(
                item: item,
                onToggle: () => onToggle(item),
                onEdit: () => onEdit(item),
                onDelete: () => onDelete(item),
              ),
              if (index < items.length - 1)
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

class _ChecklistItemTile extends StatelessWidget {
  final ChecklistItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ChecklistItemTile({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        color: AppColors.danger,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: ListTile(
        onTap: onToggle,
        leading: Checkbox(
          value: item.isPacked,
          onChanged: (_) => onToggle(),
          activeColor: AppColors.teal,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            color: item.isPacked ? AppColors.muted : AppColors.ink,
            fontWeight: FontWeight.w700,
            decoration: item.isPacked ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: item.note.isEmpty
            ? null
            : Text(
                item.note,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
        trailing: IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 19),
          color: AppColors.muted,
          tooltip: "Edit item",
        ),
      ),
    );
  }
}
