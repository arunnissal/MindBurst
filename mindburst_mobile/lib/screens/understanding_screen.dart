import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/memory_model.dart';
import '../database/db_helper.dart';
import '../services/ai_extractor.dart';
import '../services/native_service.dart';

class UnderstandingScreen extends StatefulWidget {
  final Capture capture;
  final List<Memory> initialMemories;

  const UnderstandingScreen({
    super.key,
    required this.capture,
    required this.initialMemories,
  });

  @override
  State<UnderstandingScreen> createState() => _UnderstandingScreenState();
}

class _UnderstandingScreenState extends State<UnderstandingScreen> {
  late List<Memory> _memories;
  late List<TextEditingController> _titleControllers;
  late List<TextEditingController> _catControllers;
  late List<TextEditingController> _dateControllers;
  late List<TextEditingController> _timeControllers;

  final List<String> _retentionOptions = ['Temporary', 'Keep Until Delete', 'Permanent'];
  bool _isSaving = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _memories = widget.initialMemories.map((m) => m.copyWith()).toList();
    _titleControllers = _memories.map((m) => TextEditingController(text: m.title)).toList();
    _catControllers = _memories.map((m) => TextEditingController(text: m.category)).toList();
    _dateControllers = _memories.map((m) => TextEditingController(text: m.date ?? '')).toList();
    _timeControllers = _memories.map((m) => TextEditingController(text: m.time ?? '')).toList();
  }

  @override
  void dispose() {
    for (final c in _titleControllers) c.dispose();
    for (final c in _catControllers) c.dispose();
    for (final c in _dateControllers) c.dispose();
    for (final c in _timeControllers) c.dispose();
    super.dispose();
  }

  void _cycleRetention(int index) {
    setState(() {
      final current = _memories[index].retention;
      final currentIdx = _retentionOptions.indexOf(current);
      final nextIdx = (currentIdx + 1) % _retentionOptions.length;
      _memories[index].retention = _retentionOptions[nextIdx];
    });
  }

  Future<void> _pickDate(int index) async {
    final now = DateTime.now();
    DateTime initial = now;
    if (_dateControllers[index].text.trim().isNotEmpty) {
      try {
        initial = DateTime.parse(_dateControllers[index].text.trim());
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );

    if (picked != null) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        _dateControllers[index].text = formatted;
        _memories[index].date = formatted;
      });
    }
  }

  Future<void> _pickTime(int index) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
    );

    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      final formatted = '$hour:$minute $period';
      setState(() {
        _timeControllers[index].text = formatted;
        _memories[index].time = formatted;
      });
    }
  }

  Future<void> _handleCancel() async {
    if (_isSaving || _isSaved) return;
    try {
      if (widget.capture.id != null) {
        await DatabaseHelper.instance.deleteCapture(widget.capture.id!);
      }
    } catch (_) {}
    if (mounted) Navigator.pop(context, false);
  }

  Future<void> _handleSave() async {
    if (_isSaving || _isSaved) return;
    setState(() => _isSaving = true);

    try {
      for (int i = 0; i < _memories.length; i++) {
        _memories[i].title = _titleControllers[i].text.trim().isNotEmpty
            ? _titleControllers[i].text.trim()
            : _memories[i].title;
        _memories[i].category = _catControllers[i].text.trim().isNotEmpty
            ? _catControllers[i].text.trim()
            : _memories[i].category;
        _memories[i].date = _dateControllers[i].text.trim().isNotEmpty
            ? _dateControllers[i].text.trim()
            : null;
        _memories[i].time = _timeControllers[i].text.trim().isNotEmpty
            ? _timeControllers[i].text.trim()
            : null;
      }

      await DatabaseHelper.instance.saveMemories(_memories);
      _isSaved = true;

      // Schedule exact Android AlarmManager notifications for reminders
      for (final m in _memories) {
        if (m.category == 'Reminders' || m.time != null) {
          final scheduledDt = NativeService.parseReminderDateTime(m.date, m.time);
          if (scheduledDt != null && m.id != null) {
            NativeService.scheduleNotification(
              id: m.id!,
              title: 'Reminder: ${m.title}',
              body: m.details.isNotEmpty ? m.details : m.title,
              triggerAtMillis: scheduledDt.millisecondsSinceEpoch,
            );
          }
        }
      }

      final count = _memories.length;
      final summary = count == 1
          ? _memories.first.title
          : '$count items saved and organized into categories.';
      NativeService.showNotification(
        'MindBurst Captured 🧠',
        summary,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  String _getTypeIcon(String type) {
    switch (type) {
      case 'Reminder':
        return '⏰';
      case 'Carry':
        return '🎒';
      case 'Task':
        return '✓';
      case 'Shopping':
        return '🛒';
      case 'Idea':
        return '💡';
      case 'Memory':
        return '🧠';
      default:
        return '📝';
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'reminders':
        return AppTheme.reminderAmber;
      case 'tasks':
        return AppTheme.taskIndigo;
      case 'shopping':
        return AppTheme.shoppingEmerald;
      case 'carry':
        return AppTheme.carrySky;
      case 'ideas':
        return AppTheme.ideaCyan;
      default:
        return AppTheme.noteViolet;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!_isSaving && !_isSaved) {
          await _handleCancel();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Here’s what I understood'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isSaving ? null : _handleCancel,
          ),
        ),
        body: Column(
          children: [
            // Original Thought Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR THOUGHT',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${widget.capture.originalText}"',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Review & edit before saving',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            ),

            // Extracted Memories List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: _memories.length,
                itemBuilder: (context, index) {
                  final mem = _memories[index];
                  final catColor = _getCategoryColor(mem.category);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${_getTypeIcon(mem.type)} ${mem.type}',
                                    style: TextStyle(
                                      color: catColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: catColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      mem.category,
                                      style: TextStyle(
                                        color: catColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.cardBorder),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.timer_outlined, size: 13, color: AppTheme.textSecondary),
                                label: Text(
                                  mem.retention,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                                onPressed: () => _cycleRetention(index),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Editable Title
                          TextField(
                            controller: _titleControllers[index],
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Date & Time Selectors Row
                          Row(
                            children: [
                              // Date Picker Field
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickDate(index),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.cardBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 14, color: AppTheme.primary),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            _dateControllers[index].text.isNotEmpty
                                                ? _dateControllers[index].text
                                                : 'Set Date',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _dateControllers[index].text.isNotEmpty
                                                  ? AppTheme.textPrimary
                                                  : AppTheme.textSecondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Time Picker Field
                              Expanded(
                                child: InkWell(
                                  onTap: () => _pickTime(index),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: mem.category == 'Reminders' && _timeControllers[index].text.isNotEmpty
                                            ? AppTheme.reminderAmber
                                            : AppTheme.cardBorder,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: mem.category == 'Reminders'
                                              ? AppTheme.reminderAmber
                                              : AppTheme.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            _timeControllers[index].text.isNotEmpty
                                                ? _timeControllers[index].text
                                                : 'Set Time',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: _timeControllers[index].text.isNotEmpty
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: _timeControllers[index].text.isNotEmpty
                                                  ? (_memories[index].category == 'Reminders' ? AppTheme.reminderAmber : AppTheme.textPrimary)
                                                  : AppTheme.textSecondary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Extracted Entities (items, places, projects - no people names)
                          if (mem.items.isNotEmpty || mem.places.isNotEmpty || mem.projects.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                ...mem.items.map((i) => _buildEntityChip('🎒 $i')),
                                ...mem.places.map((pl) => _buildEntityChip('📍 $pl')),
                                ...mem.projects.map((pr) => _buildEntityChip('📁 $pr')),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Buttons
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.cardBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isSaving ? null : _handleCancel,
                        child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        onPressed: _isSaving ? null : _handleSave,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                '✓ Save Memories',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder, width: 0.8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
      ),
    );
  }
}
