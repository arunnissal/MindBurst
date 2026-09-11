import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/memory_model.dart';
import '../database/db_helper.dart';

class RecentlyDeletedScreen extends StatefulWidget {
  const RecentlyDeletedScreen({super.key});

  @override
  State<RecentlyDeletedScreen> createState() => _RecentlyDeletedScreenState();
}

class _RecentlyDeletedScreenState extends State<RecentlyDeletedScreen> {
  List<Memory> _deletedMemories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeleted();
  }

  Future<void> _loadDeleted() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.getDeletedMemories();
    setState(() {
      _deletedMemories = list;
      _isLoading = false;
    });
  }

  Future<void> _restoreMemory(Memory mem) async {
    if (mem.id == null) return;
    await DatabaseHelper.instance.restoreMemory(mem.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restored "${mem.title}"')),
    );
    _loadDeleted();
  }

  Future<void> _confirmDeleteForever(Memory mem) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Forever?'),
        content: Text('Are you sure you want to permanently delete "${mem.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deleteRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed == true && mem.id != null) {
      await DatabaseHelper.instance.deleteForever(mem.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permanently deleted "${mem.title}"')),
      );
      _loadDeleted();
    }
  }

  Future<void> _emptyTrash() async {
    if (_deletedMemories.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: const Text('Are you sure you want to permanently delete ALL items in the trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.deleteRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empty All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final m in _deletedMemories) {
        if (m.id != null) {
          await DatabaseHelper.instance.deleteForever(m.id!);
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trash emptied')),
      );
      _loadDeleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently Deleted'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
        actions: [
          if (_deletedMemories.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: AppTheme.deleteRed),
              tooltip: 'Empty Trash',
              onPressed: _emptyTrash,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.goldAccent))
          : _deletedMemories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 72, color: AppTheme.textSecondary.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      const Text(
                        'Trash is empty',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Deleted memories will show up here',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _deletedMemories.length,
                  itemBuilder: (context, index) {
                    final mem = _deletedMemories[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.goldAccentLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    mem.category,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.goldAccent,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (mem.deletedAt != null)
                                  Text(
                                    'Deleted: ${mem.deletedAt!.substring(0, 10)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              mem.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (mem.details.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                mem.details,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.goldAccent,
                                    side: const BorderSide(color: AppTheme.goldBorder),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.restore, size: 18),
                                  label: const Text('Restore'),
                                  onPressed: () => _restoreMemory(mem),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.deleteRed,
                                    side: const BorderSide(color: AppTheme.deleteRed),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.delete_forever, size: 18),
                                  label: const Text('Delete Forever'),
                                  onPressed: () => _confirmDeleteForever(mem),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
