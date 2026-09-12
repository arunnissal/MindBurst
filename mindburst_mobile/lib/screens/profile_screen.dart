import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../theme/app_theme.dart';
import '../models/memory_model.dart';
import '../database/db_helper.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const ProfileScreen({super.key, this.onProfileUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  UserProfile _profile = UserProfile();
  List<RecurringBill> _bills = [];
  int _totalMemories = 0;
  int _totalCaptures = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final profile = await DatabaseHelper.instance.getUserProfile();
    final bills = await DatabaseHelper.instance.getRecurringBills();
    final memories = await DatabaseHelper.instance.getActiveMemories();
    final db = await DatabaseHelper.instance.database;
    final captureCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM captures')) ?? 0;

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _bills = bills;
      _totalMemories = memories.length;
      _totalCaptures = captureCount;
      _isLoading = false;
    });
  }

  Future<void> _updateLivingSituation(String situation) async {
    final updated = _profile.copyWith(livingSituation: situation);
    setState(() => _profile = updated);
    await DatabaseHelper.instance.saveUserProfile(updated);
    widget.onProfileUpdated?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          situation == 'hostel'
              ? '🏢 Switched to Hostel Mode (Rent & Mess activated)'
              : '🏡 Switched to Home Mode (Simplified personal focus)',
        ),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _updateRentDay(int day) async {
    final updated = _profile.copyWith(rentDueDay: day);
    setState(() => _profile = updated);
    await DatabaseHelper.instance.saveUserProfile(updated);
    widget.onProfileUpdated?.call();
  }

  Future<void> _updateMessDay(int day) async {
    final updated = _profile.copyWith(messDueDay: day);
    setState(() => _profile = updated);
    await DatabaseHelper.instance.saveUserProfile(updated);
    widget.onProfileUpdated?.call();
  }

  Future<void> _toggleMessFee(bool enabled) async {
    final updated = _profile.copyWith(hasMessFee: enabled);
    setState(() => _profile = updated);
    await DatabaseHelper.instance.saveUserProfile(updated);
    widget.onProfileUpdated?.call();
  }

  Future<void> _addRecurringBillDialog() async {
    final titleController = TextEditingController();
    int selectedDay = 1;

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
                    'Add Recurring Bill / Payment',
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
                      hintText: 'e.g., Room WiFi, Gym, Mobile Recharge',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Due Day of Month:',
                        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          'Day $selectedDay',
                          style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: selectedDay.toDouble(),
                    min: 1,
                    max: 31,
                    divisions: 30,
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.cardBorder,
                    onChanged: (val) {
                      setSheetState(() => selectedDay = val.round());
                    },
                  ),
                  const SizedBox(height: 16),
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
                          final bill = RecurringBill(
                            title: title,
                            dueDay: selectedDay,
                            category: _profile.livingSituation == 'hostel' ? 'Hostel' : 'Personal',
                          );
                          await DatabaseHelper.instance.addRecurringBill(bill);
                          Navigator.pop(ctx);
                          _loadProfileData();
                        }
                      },
                      child: const Text('Add Recurring Bill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Future<void> _deleteBill(int id) async {
    await DatabaseHelper.instance.deleteRecurringBill(id);
    _loadProfileData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final isHostel = _profile.livingSituation == 'hostel';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.person_pin, color: AppTheme.primaryLight, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile & Context',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Personalized Second Brain Context',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Section: Living Situation
                    const Text(
                      'LIVING SITUATION',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildLivingOption(
                            title: 'Hostel / PG',
                            subtitle: 'Room, rent & mess sync',
                            icon: Icons.apartment_rounded,
                            isSelected: isHostel,
                            onTap: () => _updateLivingSituation('hostel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildLivingOption(
                            title: 'Home',
                            subtitle: 'Day scholar & family life',
                            icon: Icons.home_rounded,
                            isSelected: !isHostel,
                            onTap: () => _updateLivingSituation('home'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Section: Hostel Recurring Obligations (Only when Hostel is active)
                    if (isHostel) ...[
                      const Text(
                        'HOSTEL MONTHLY DUES',
                        style: TextStyle(
                          color: AppTheme.goldAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
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
                                const Row(
                                  children: [
                                    Icon(Icons.calendar_month, color: AppTheme.goldAccent, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Hostel Rent Due Date',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.goldAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.goldAccent.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    'Day ${_profile.rentDueDay}',
                                    style: const TextStyle(
                                      color: AppTheme.goldAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Choose the day of every month you pay your room rent:',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            Slider(
                              value: _profile.rentDueDay.toDouble(),
                              min: 1,
                              max: 31,
                              divisions: 30,
                              activeColor: AppTheme.goldAccent,
                              inactiveColor: AppTheme.cardBorder,
                              onChanged: (val) => _updateRentDay(val.round()),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [1, 5, 10, 15, 25].map((d) {
                                final isChosen = _profile.rentDueDay == d;
                                return ChoiceChip(
                                  label: Text('Day $d'),
                                  selected: isChosen,
                                  selectedColor: AppTheme.goldAccent.withOpacity(0.2),
                                  backgroundColor: AppTheme.surfaceBg,
                                  labelStyle: TextStyle(
                                    color: isChosen ? AppTheme.goldAccent : AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  onSelected: (_) => _updateRentDay(d),
                                );
                              }).toList(),
                            ),
                            const Divider(color: AppTheme.cardBorder, height: 24),

                            // Mess Fee Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.restaurant_menu, color: AppTheme.primaryLight, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Mess Fee Due Date',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _profile.hasMessFee,
                                  activeColor: AppTheme.primary,
                                  onChanged: _toggleMessFee,
                                ),
                              ],
                            ),
                            if (_profile.hasMessFee) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Paid separately on:',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      'Day ${_profile.messDueDay}',
                                      style: const TextStyle(
                                        color: AppTheme.primaryLight,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: _profile.messDueDay.toDouble(),
                                min: 1,
                                max: 31,
                                divisions: 30,
                                activeColor: AppTheme.primary,
                                inactiveColor: AppTheme.cardBorder,
                                onChanged: (val) => _updateMessDay(val.round()),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Section: Custom Recurring Bills (WiFi, Gym, Mobile)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CUSTOM RECURRING BILLS',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addRecurringBillDialog,
                          icon: const Icon(Icons.add, size: 16, color: AppTheme.primaryLight),
                          label: const Text('Add Bill', style: TextStyle(color: AppTheme.primaryLight, fontSize: 12)),
                        ),
                      ],
                    ),
                    if (_bills.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: const Text(
                          'No custom bills added. Tap "+ Add Bill" to track WiFi, Gym, or Recharges.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      )
                    else
                      ..._bills.map((b) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.receipt_long, color: AppTheme.primaryLight, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b.title,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'Every month on Day ${b.dueDay}',
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textSecondary),
                                  onPressed: () => b.id != null ? _deleteBill(b.id!) : null,
                                ),
                              ],
                            ),
                          )),
                    const SizedBox(height: 24),

                    // Section: Second Brain Health
                    const Text(
                      'SECOND BRAIN STATUS',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatItem('Active Memories', '$_totalMemories', Icons.psychology),
                              _buildStatItem('Raw Captures', '$_totalCaptures', Icons.bolt),
                              _buildStatItem('Storage', '100% Local', Icons.security),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: AppTheme.greenAccent, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'SQLite Database (Zero cloud leakage, completely private)',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivingOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.15) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: isSelected ? AppTheme.primaryLight : AppTheme.textSecondary, size: 24),
                if (isSelected)
                  const Icon(Icons.check_circle, color: AppTheme.primaryLight, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryLight, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}
