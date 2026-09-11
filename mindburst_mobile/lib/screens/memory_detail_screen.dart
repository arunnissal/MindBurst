import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/memory_model.dart';
import '../database/db_helper.dart';
import '../services/ai_extractor.dart';
import '../services/native_service.dart';

class MemoryDetailScreen extends StatefulWidget {
  final Memory memory;
  const MemoryDetailScreen({super.key, required this.memory});

  @override
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen> {
  late Memory _memory;
  bool _isEditing = false;

  late TextEditingController _titleController;
  late TextEditingController _detailsController;
  late TextEditingController _dateController;
  late TextEditingController _timeController;
  late TextEditingController _categoryController;
  late String _retention;

  final List<String> _retentionOptions = ['Temporary', 'Keep Until Delete', 'Permanent'];

  @override
  void initState() {
    super.initState();
    _memory = widget.memory;
    _initControllers();
  }

  void _initControllers() {
    _titleController = TextEditingController(text: _memory.title);
    _detailsController = TextEditingController(text: _memory.details);
    _dateController = TextEditingController(text: _memory.date ?? '');
    _timeController = TextEditingController(text: _memory.time ?? '');
    _categoryController = TextEditingController(text: _memory.category);
    _retention = _memory.retention;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _handleCompleteToggle() async {
    await DatabaseHelper.instance.toggleComplete(_memory);
    setState(() {});
  }

  Future<void> _handleSaveEdit() async {
    setState(() {
      _memory.title = _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : _memory.title;
      _memory.details = _detailsController.text.trim();
      _memory.date = _dateController.text.trim().isNotEmpty ? _dateController.text.trim() : null;
      _memory.time = _timeController.text.trim().isNotEmpty ? _timeController.text.trim() : null;
      _memory.category = _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : _memory.category;
      _memory.retention = _retention;
      _isEditing = false;
    });
    await DatabaseHelper.instance.updateMemory(_memory);

    if (_memory.category == 'Reminders' || _memory.time != null) {
      final scheduledDt = NativeService.parseReminderDateTime(_memory.date, _memory.time);
      if (scheduledDt != null && _memory.id != null) {
        NativeService.scheduleNotification(
          id: _memory.id!,
          title: 'Reminder: ${_memory.title}',
          body: _memory.details.isNotEmpty ? _memory.details : _memory.title,
          triggerAtMillis: scheduledDt.millisecondsSinceEpoch,
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this memory?'),
        content: const Text('This memory will be moved to Recently Deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.deleteRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.softDelete(_memory.id!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Memory' : 'Memory Detail'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: _isEditing ? _buildEditMode() : _buildViewMode(),
      ),
      bottomNavigationBar: _isEditing ? null : _buildBottomActions(),
    );
  }

  Widget _buildViewMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category & Retention Badges
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.goldAccentLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.goldBorder),
              ),
              child: Text(
                _memory.category.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.goldAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              '⏳ ${_memory.retention}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Title
        Text(
          _memory.completed ? '✔ ${_memory.title}' : _memory.title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _memory.completed ? AppTheme.textSecondary : AppTheme.textPrimary,
            decoration: _memory.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(height: 8),

        // Date & Time
        Row(
          children: [
            Text(
              '📅 Scheduled: ${AIExtractor.formatHumanDate(_memory.date)}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            if (_memory.time != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.reminderAmberLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.alarm, size: 12, color: AppTheme.reminderAmber),
                    const SizedBox(width: 3),
                    Text(
                      _memory.time!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.reminderAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        // Original Thought Quote Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR THOUGHT / DETAILS',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _memory.details.isNotEmpty ? _memory.details : '"${_memory.originalText ?? ""}"',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Extracted Entities (Places, Items, Projects - NO people names)
        if (_memory.places.isNotEmpty) _buildEntityRow('📍 Places', _memory.places.join(', ')),
        if (_memory.items.isNotEmpty) _buildEntityRow('🎒 Items', _memory.items.join(', ')),
        if (_memory.projects.isNotEmpty) _buildEntityRow('📁 Projects', _memory.projects.join(', ')),
      ],
    );
  }

  Widget _buildEntityRow(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _detailsController,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Details'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _categoryController,
          decoration: const InputDecoration(labelText: 'Category'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _dateController,
          decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD or Tomorrow)'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _timeController,
          decoration: const InputDecoration(
            labelText: 'Reminder Time (e.g. 7:40 PM)',
            hintText: '7:40 PM',
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _retention,
          decoration: const InputDecoration(labelText: 'Retention Mode'),
          items: _retentionOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _retention = val);
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _isEditing = false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.goldAccent, foregroundColor: Colors.white),
                onPressed: _handleSaveEdit,
                child: const Text('Save Edits'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(_memory.completed ? Icons.replay : Icons.check),
                label: Text(_memory.completed ? 'Reopen' : 'Complete', style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _handleCompleteToggle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.deleteRed,
                  side: const BorderSide(color: AppTheme.deleteRed),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                onPressed: _handleDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
