import 'package:flutter/material.dart';
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
  }

  @override
  void dispose() {
    for (final c in _titleControllers) {
      c.dispose();
    }
    for (final c in _catControllers) {
      c.dispose();
    }
    for (final c in _dateControllers) {
      c.dispose();
    }
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
      }

      await DatabaseHelper.instance.saveMemories(_memories);
      _isSaved = true;

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
          title: const Text('Here’s what I understood.'),
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
                color: AppTheme.goldAccentLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.goldBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR THOUGHT',
                    style: TextStyle(
                      color: AppTheme.goldAccent,
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
                              Text(
                                '${_getTypeIcon(mem.type)} ${mem.type}',
                                style: const TextStyle(
                                  color: AppTheme.goldAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '[${mem.category}]',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

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

                          // Category & Date Row
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _catControllers[index],
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _dateControllers[index],
                                  style: const TextStyle(fontSize: 13),
                                  decoration: const InputDecoration(
                                    labelText: 'Date (YYYY-MM-DD)',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Retention & Human Date Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '🗓️ ${AIExtractor.formatHumanDate(mem.date)}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.goldBorder),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.timer_outlined, size: 14, color: AppTheme.goldAccent),
                                label: Text(
                                  mem.retention,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                                ),
                                onPressed: () => _cycleRetention(index),
                              ),
                            ],
                          ),

                          // Extracted Entities
                          if (mem.items.isNotEmpty || mem.people.isNotEmpty || mem.places.isNotEmpty || mem.projects.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                ...mem.items.map((i) => _buildEntityChip('🎒 $i')),
                                ...mem.people.map((p) => _buildEntityChip('👤 $p')),
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

            // Bottom Buttons [ Cancel ] [ Save ]
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.goldBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSaving ? null : _handleCancel,
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.goldAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSaving ? null : _handleSave,
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                            )
                          : const Text('✓ Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
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
        color: AppTheme.goldAccentLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
      ),
    );
  }
}
