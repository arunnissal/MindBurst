import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/memory_model.dart';
import '../database/db_helper.dart';
import 'memory_detail_screen.dart';
import 'recently_deleted_screen.dart';

class AllScreen extends StatefulWidget {
  const AllScreen({super.key});

  @override
  State<AllScreen> createState() => AllScreenState();
}

class AllScreenState extends State<AllScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Memory> _memories = [];
  bool _isLoading = true;

  String _selectedDateFilter = 'All'; // 'All', 'Today', 'Yesterday', 'This Week'
  String _selectedCategory = 'All';
  String _selectedRetention = 'All';

  final List<String> _categories = [
    'All',
    'Reminders',
    'Tasks',
    'Events',
    'Carry',
    'Notes',
    'Places',
    'Projects',
  ];

  final List<String> _dateFilters = ['All', 'Today', 'Yesterday', 'This Week'];

  @override
  void initState() {
    super.initState();
    refreshMemories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> refreshMemories() async {
    setState(() => _isLoading = true);

    String? startDate;
    String? endDate;
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');

    if (_selectedDateFilter == 'Today') {
      startDate = fmt.format(now);
      endDate = startDate;
    } else if (_selectedDateFilter == 'Yesterday') {
      final yest = now.subtract(const Duration(days: 1));
      startDate = fmt.format(yest);
      endDate = startDate;
    } else if (_selectedDateFilter == 'This Week') {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      startDate = fmt.format(monday);
      endDate = fmt.format(sunday);
    }

    final results = await DatabaseHelper.instance.getActiveMemories(
      query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      category: _selectedCategory,
      retention: _selectedRetention,
      startDate: startDate,
      endDate: endDate,
    );

    if (!mounted) return;
    setState(() {
      _memories = results;
      _isLoading = false;
    });
  }

  Future<void> _toggleComplete(Memory mem) async {
    await DatabaseHelper.instance.toggleComplete(mem);
    await refreshMemories();
  }

  Future<void> _softDelete(Memory mem) async {
    if (mem.id == null) return;
    await DatabaseHelper.instance.softDelete(mem.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${mem.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: AppTheme.goldAccent,
          onPressed: () async {
            await DatabaseHelper.instance.restoreMemory(mem.id!);
            refreshMemories();
          },
        ),
      ),
    );
    refreshMemories();
  }

  Future<void> _openDetail(Memory mem) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MemoryDetailScreen(memory: mem)),
    );
    refreshMemories();
  }

  Future<void> _openTrash() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const RecentlyDeletedScreen()),
    );
    if (updated == true) {
      refreshMemories();
    }
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.goldAccent,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppTheme.textPrimary,
        ),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppTheme.goldAccent : AppTheme.goldBorder,
          ),
        ),
        onSelected: (_) => onSelected(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MEMORIES ✦'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.goldAccent),
            tooltip: 'Recently Deleted',
            onPressed: _openTrash,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters container
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              color: AppTheme.background,
              border: Border(
                bottom: BorderSide(color: AppTheme.goldBorder, width: 0.8),
              ),
            ),
            child: Column(
              children: [
                // Search TextField
                TextField(
                  controller: _searchController,
                  onChanged: (_) => refreshMemories(),
                  decoration: InputDecoration(
                    hintText: 'Search memories, items, people, places...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.goldAccent, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              refreshMemories();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 8),

                // Date Filters
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _dateFilters.length,
                    itemBuilder: (context, index) {
                      final filter = _dateFilters[index];
                      return _buildChip(
                        filter,
                        _selectedDateFilter == filter,
                        () {
                          setState(() => _selectedDateFilter = filter);
                          refreshMemories();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),

                // Category Filters
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      return _buildChip(
                        cat,
                        _selectedCategory == cat,
                        () {
                          setState(() => _selectedCategory = cat);
                          refreshMemories();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Count bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_memories.length} ${_memories.length == 1 ? 'memory' : 'memories'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                // Retention filter popup
                PopupMenuButton<String>(
                  initialValue: _selectedRetention,
                  onSelected: (val) {
                    setState(() => _selectedRetention = val);
                    refreshMemories();
                  },
                  child: Row(
                    children: [
                      Text(
                        'Retention: $_selectedRetention',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.goldAccent,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: AppTheme.goldAccent, size: 18),
                    ],
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'All', child: Text('All')),
                    const PopupMenuItem(value: 'Permanent', child: Text('Permanent')),
                    const PopupMenuItem(value: 'Temporary', child: Text('Temporary')),
                    const PopupMenuItem(value: 'Keep Until Delete', child: Text('Keep Until Delete')),
                  ],
                ),
              ],
            ),
          ),

          // Memory Feed List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.goldAccent))
                : _memories.isEmpty
                    ? RefreshIndicator(
                        color: AppTheme.goldAccent,
                        onRefresh: refreshMemories,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                            Icon(Icons.bubble_chart_outlined, size: 72, color: AppTheme.goldAccent.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            const Center(
                              child: Text(
                                'No memories found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Center(
                              child: Text(
                                'Tap Burst to capture and split thoughts instantly!',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.goldAccent,
                        onRefresh: refreshMemories,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: _memories.length,
                          itemBuilder: (context, index) {
                            final mem = _memories[index];
                            return _buildMemoryCard(mem);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(Memory mem) {
    final bool isCompleted = mem.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetail(mem),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Category Badge, Date/Time, Retention, Delete
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Completion Checkbox
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: isCompleted,
                      activeColor: AppTheme.goldAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (_) => _toggleComplete(mem),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Category tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.goldAccentLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.goldBorder, width: 0.5),
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

                  const SizedBox(width: 8),

                  // Retention badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: mem.retention == 'Permanent'
                          ? Colors.purple.withOpacity(0.08)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      mem.retention,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: mem.retention == 'Permanent' ? Colors.purple : AppTheme.textSecondary,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Date badge if available
                  if (mem.date != null)
                    Row(
                      children: [
                        const Icon(Icons.event, size: 13, color: AppTheme.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          mem.date!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(width: 6),

                  // Quick Delete button
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textSecondary),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: () => _softDelete(mem),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Title
              Padding(
                padding: const EdgeInsets.only(left: 32.0),
                child: Text(
                  mem.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),

              // Details
              if (mem.details.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 32.0),
                  child: Text(
                    mem.details,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary.withOpacity(0.85),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              // Entities chips (People, Places, Items, Projects)
              if (mem.people.isNotEmpty || mem.places.isNotEmpty || mem.items.isNotEmpty || mem.projects.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 32.0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ...mem.people.map((p) => _buildEntityBadge(p, Icons.person, Colors.blue.shade700, Colors.blue.shade50)),
                      ...mem.places.map((p) => _buildEntityBadge(p, Icons.place, Colors.green.shade700, Colors.green.shade50)),
                      ...mem.items.map((i) => _buildEntityBadge(i, Icons.shopping_bag_outlined, Colors.orange.shade800, Colors.orange.shade50)),
                      ...mem.projects.map((pr) => _buildEntityBadge(pr, Icons.folder_outlined, Colors.purple.shade700, Colors.purple.shade50)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntityBadge(String name, IconData icon, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 3),
          Text(
            name,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }
}
