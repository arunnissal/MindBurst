import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/memory_model.dart';
import '../database/db_helper.dart';
import '../services/native_service.dart';
import '../services/ai_extractor.dart';
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

  int _selectedView = 0; // 0: Memories, 1: Daily Routine
  List<DailyRoutine> _routines = [];
  UserProfile _userProfile = UserProfile();

  List<String> get _categories {
    final living = _userProfile.livingSituation;
    final prof = _userProfile.profession;

    final base = ['All', 'Reminders', 'Tasks'];
    if (living == 'hostel') {
      base.add('Hostel');
    } else if (living == 'rented') {
      base.add('Rent');
    } else {
      base.add('Home');
    }

    if (prof == 'student') {
      base.add('College');
    } else if (prof == 'professional') {
      base.add('Work');
    } else if (prof == 'business') {
      base.add('Business');
    } else {
      base.add('Family');
    }

    base.addAll(['Carry', 'Shopping', 'Notes', 'Places']);
    return base;
  }

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

    final profile = await DatabaseHelper.instance.getUserProfile();
    final routines = await DatabaseHelper.instance.getDailyRoutines(
      contextTag: profile.livingSituation,
    );

    if (!mounted) return;
    setState(() {
      _userProfile = profile;
      _routines = routines;
      _memories = results;
      _isLoading = false;
    });
  }

  Future<void> _toggleRoutine(DailyRoutine routine) async {
    await DatabaseHelper.instance.toggleRoutineCompletion(routine);
    await refreshMemories();
  }

  Future<void> _deleteRoutine(int id) async {
    await DatabaseHelper.instance.deleteDailyRoutine(id);
    await refreshMemories();
  }

  Future<void> _addRoutineDialog() async {
    final titleController = TextEditingController();
    String selectedSlot = 'Morning';
    String selectedContext = 'all';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Daily Habit / Routine',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'e.g., Morning Walk, Night Study, Wash Clothes',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.surfaceBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Time Slot:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Morning', 'Afternoon', 'Evening', 'Night'].map((slot) {
                      final isChosen = selectedSlot == slot;
                      return ChoiceChip(
                        label: Text(slot),
                        selected: isChosen,
                        selectedColor: AppTheme.primary.withOpacity(0.25),
                        backgroundColor: AppTheme.surfaceBg,
                        labelStyle: TextStyle(
                          color: isChosen ? AppTheme.primaryLight : AppTheme.textSecondary,
                          fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setSheetState(() => selectedSlot = slot),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text('Applicable Context:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      {'tag': 'all', 'label': 'Everywhere (All)'},
                      {'tag': 'hostel', 'label': '🏢 Hostel Only'},
                      {'tag': 'home', 'label': '🏡 Home Only'},
                    ].map((ctxItem) {
                      final isChosen = selectedContext == ctxItem['tag'];
                      return ChoiceChip(
                        label: Text(ctxItem['label']!),
                        selected: isChosen,
                        selectedColor: AppTheme.primary.withOpacity(0.25),
                        backgroundColor: AppTheme.surfaceBg,
                        labelStyle: TextStyle(
                          color: isChosen ? AppTheme.primaryLight : AppTheme.textSecondary,
                          fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setSheetState(() => selectedContext = ctxItem['tag']!),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isNotEmpty) {
                          final routine = DailyRoutine(
                            title: title,
                            timeSlot: selectedSlot,
                            contextTag: selectedContext,
                          );
                          await DatabaseHelper.instance.addDailyRoutine(routine);
                          Navigator.pop(ctx);
                          refreshMemories();
                        }
                      },
                      child: const Text('Add Routine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
          // Top Segment: [💭 Memories] vs [⚡ Daily Routine]
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedView = 0),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedView == 0 ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.layers_outlined, size: 16, color: _selectedView == 0 ? Colors.white : AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Memories',
                            style: TextStyle(
                              color: _selectedView == 0 ? Colors.white : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedView = 1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedView == 1 ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt, size: 16, color: _selectedView == 1 ? Colors.white : AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Daily Routine',
                            style: TextStyle(
                              color: _selectedView == 1 ? Colors.white : AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedView == 1)
            Expanded(child: _buildDailyRoutineView())
          else ...[
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
                    hintText: 'Search memories, places, tasks, items...',
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
        ],
      ),
    );
  }

  Widget _buildDailyRoutineView() {
    final completedCount = _routines.where((r) => r.isCompleted).length;
    final totalCount = _routines.length;
    final percent = totalCount > 0 ? (completedCount / totalCount) : 0.0;
    final isHostel = _userProfile.livingSituation == 'hostel';

    return Column(
      children: [
        // Daily summary card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isHostel ? '🏢 Hostel Routine' : '🏡 Home Routine',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '$completedCount of $totalCount Done',
                      style: const TextStyle(
                        color: AppTheme.goldAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 6,
                    backgroundColor: AppTheme.surfaceBg,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.goldAccent),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d').format(DateTime.now()),
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    InkWell(
                      onTap: _addRoutineDialog,
                      child: const Row(
                        children: [
                          Icon(Icons.add_circle_outline, size: 14, color: AppTheme.primaryLight),
                          SizedBox(width: 4),
                          Text(
                            'Add Habit',
                            style: TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // List of routines
        Expanded(
          child: _routines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bolt, size: 48, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      const Text(
                        'No routines set for your profile.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                        onPressed: _addRoutineDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Daily Habit'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _routines.length,
                  itemBuilder: (context, index) {
                    final routine = _routines[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: routine.isCompleted ? AppTheme.greenAccent.withOpacity(0.4) : AppTheme.cardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => _toggleRoutine(routine),
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: routine.isCompleted ? AppTheme.greenAccent : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: routine.isCompleted ? AppTheme.greenAccent : AppTheme.cardBorder,
                                  width: 2,
                                ),
                              ),
                              child: routine.isCompleted
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  routine.title,
                                  style: TextStyle(
                                    color: routine.isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    decoration: routine.isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        routine.timeSlot,
                                        style: const TextStyle(color: AppTheme.primaryLight, fontSize: 10),
                                      ),
                                    ),
                                    if (routine.streakCount > 0) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        '🔥 ${routine.streakCount} streak',
                                        style: const TextStyle(color: AppTheme.goldAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textSecondary),
                            onPressed: () => routine.id != null ? _deleteRoutine(routine.id!) : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
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
      case 'events':
        return AppTheme.eventRose;
      default:
        return AppTheme.noteViolet;
    }
  }

  Future<void> _handleReminderTap(Memory mem) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.alarm, color: AppTheme.reminderAmber, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mem.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                mem.time != null
                    ? 'Current alert: ${mem.date ?? "Today"} at ${mem.time}'
                    : 'No reminder time set yet.',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.edit_calendar, color: AppTheme.primary),
                title: Text(mem.time != null ? 'Change Reminder Time' : 'Set Reminder Time'),
                subtitle: const Text('Pick exact date & time for Android notification'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _setMemoryReminderTime(mem);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined, color: AppTheme.reminderAmber),
                title: const Text('Test Alert Now'),
                subtitle: const Text('Trigger immediate phone notification'),
                onTap: () {
                  Navigator.pop(ctx);
                  NativeService.showNotification(
                    mem.title,
                    '${mem.category} • ${mem.date != null ? AIExtractor.formatHumanDate(mem.date) : "Reminder"}${mem.time != null ? " at ${mem.time}" : ""}',
                    id: mem.id,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🔔 Notification triggered for "${mem.title}"'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              if (mem.time != null)
                ListTile(
                  leading: const Icon(Icons.alarm_off, color: AppTheme.deleteRed),
                  title: const Text('Remove Reminder Time', style: TextStyle(color: AppTheme.deleteRed)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (mem.id != null) {
                      NativeService.cancelNotification(mem.id!);
                      mem.time = null;
                      await DatabaseHelper.instance.updateMemory(mem);
                      refreshMemories();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reminder alert cancelled.')),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setMemoryReminderTime(Memory mem) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: mem.date != null ? (DateTime.tryParse(mem.date!) ?? now) : now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null) return;

    final hour = pickedTime.hourOfPeriod == 0 ? 12 : pickedTime.hourOfPeriod;
    final minute = pickedTime.minute.toString().padLeft(2, '0');
    final period = pickedTime.period == DayPeriod.am ? 'AM' : 'PM';
    final formattedTime = '$hour:$minute $period';
    final formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);

    mem.date = formattedDate;
    mem.time = formattedTime;
    if (mem.category == 'Notes') {
      mem.category = 'Reminders';
      mem.type = 'Reminder';
    }

    if (mem.id != null) {
      await DatabaseHelper.instance.updateMemory(mem);

      final scheduledDt = NativeService.parseReminderDateTime(formattedDate, formattedTime);
      if (scheduledDt != null) {
        await NativeService.scheduleNotification(
          id: mem.id!,
          title: 'Reminder: ${mem.title}',
          body: mem.details.isNotEmpty ? mem.details : mem.title,
          triggerAtMillis: scheduledDt.millisecondsSinceEpoch,
        );
      }

      refreshMemories();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏰ Reminder set for $formattedDate at $formattedTime'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  Widget _buildMemoryCard(Memory mem) {
    final bool isCompleted = mem.completed;
    final catColor = _getCategoryColor(mem.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(mem),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Checkbox, Category Badge, Retention, Date/Time, Bell, Delete
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Completion Checkbox
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: isCompleted,
                      activeColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (_) => _toggleComplete(mem),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Category tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      mem.category,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: catColor,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

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
                        const Icon(Icons.event, size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          mem.date!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                  // Time badge if available
                  if (mem.time != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _handleReminderTap(mem),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.reminderAmberLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.reminderAmber.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.alarm, size: 11, color: AppTheme.reminderAmber),
                            const SizedBox(width: 2),
                            Text(
                              mem.time!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.reminderAmber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(width: 4),

                  // Reminder Bell button
                  IconButton(
                    icon: Icon(
                      mem.time != null ? Icons.notifications_active : Icons.notifications_none,
                      size: 18,
                      color: mem.time != null ? AppTheme.reminderAmber : AppTheme.primary,
                    ),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    tooltip: 'Set Reminder',
                    onPressed: () => _handleReminderTap(mem),
                  ),

                  const SizedBox(width: 2),

                  // Quick Delete button
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textSecondary),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
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

              // Entities chips (Places, Items, Projects - NO people names)
              if (mem.places.isNotEmpty || mem.items.isNotEmpty || mem.projects.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 32.0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
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
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        if (icon == Icons.place) {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.place, color: Colors.green, size: 28),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: const Text('Detected Location'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.map_outlined, color: AppTheme.goldAccent),
                    title: const Text('Open in Google Maps'),
                    subtitle: const Text('Pin location and navigate'),
                    onTap: () {
                      Navigator.pop(ctx);
                      NativeService.openMaps(name);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.filter_list, color: AppTheme.goldAccent),
                    title: const Text('Filter memories for this place'),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _searchController.text = name);
                      refreshMemories();
                    },
                  ),
                ],
              ),
            ),
          );
        } else {
          setState(() {
            _searchController.text = name;
          });
          refreshMemories();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: textColor.withValues(alpha: 0.2), width: 0.5),
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
      ),
    );
  }
}
