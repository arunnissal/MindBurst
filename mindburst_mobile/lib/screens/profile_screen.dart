import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../theme/app_theme.dart';
import '../models/memory_model.dart';
import '../database/db_helper.dart';
import '../services/vault_storage_service.dart';

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
  VaultStats? _vaultStats;

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
    final vaultStats = await VaultStorageService.instance.getVaultStats();

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _bills = bills;
      _totalMemories = memories.length;
      _totalCaptures = captureCount;
      _vaultStats = vaultStats;
      _isLoading = false;
    });
  }

  Future<void> _updateProfession(String prof) async {
    final updated = _profile.copyWith(profession: prof);
    setState(() => _profile = updated);
    await DatabaseHelper.instance.saveUserProfile(updated);
    widget.onProfileUpdated?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched role to ${_getProfessionName(prof)}'),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _getProfessionName(String prof) {
    switch (prof) {
      case 'professional':
        return 'Working Professional 💼';
      case 'homemaker':
        return 'Homemaker / Family 🏡';
      case 'business':
        return 'Business / Freelance 🚀';
      default:
        return 'Student / Scholar 🎓';
    }
  }

  Future<void> _updateLivingSituation(String situation) async {
    final updated = _profile.copyWith(livingSituation: situation);
    setState(() => _profile = updated);
    await DatabaseHelper.instance.saveUserProfile(updated);
    widget.onProfileUpdated?.call();
    if (!mounted) return;

    String msg = '🏡 Switched to Family Home Mode (Simplified personal focus)';
    if (situation == 'hostel') {
      msg = '🛏️ Switched to Hostel/PG Mode (Rent & Mess fee active)';
    } else if (situation == 'rented') {
      msg = '🏢 Switched to Rented House Mode (House rent active)';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
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
    final isRented = _profile.livingSituation == 'rented';

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
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Personal Context',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Adapts MindBurst to your life',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section: Profession / Role
                    const Text(
                      'DAILY ROLE / PROFESSION',
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
                          child: _buildRoleCard('student', 'Student', 'College & study', Icons.school_outlined),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildRoleCard('professional', 'Worker', 'Office & career', Icons.business_center_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRoleCard('homemaker', 'Homemaker', 'Family & home', Icons.family_restroom_outlined),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildRoleCard('business', 'Freelance/Biz', 'Clients & growth', Icons.rocket_launch_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Section: Living Situation
                    const Text(
                      'LIVING ARRANGEMENT',
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
                            subtitle: 'Room & mess sync',
                            icon: Icons.apartment_rounded,
                            isSelected: _profile.livingSituation == 'hostel',
                            onTap: () => _updateLivingSituation('hostel'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildLivingOption(
                            title: 'Rented House',
                            subtitle: 'Rent & utilities',
                            icon: Icons.location_city_rounded,
                            isSelected: _profile.livingSituation == 'rented',
                            onTap: () => _updateLivingSituation('rented'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildLivingOption(
                            title: 'Family Home',
                            subtitle: 'Own family home',
                            icon: Icons.home_rounded,
                            isSelected: _profile.livingSituation == 'home',
                            onTap: () => _updateLivingSituation('home'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Section: Recurring Obligations (Only when Hostel or Rented House is active)
                    if (isHostel || isRented) ...[
                      Text(
                        isHostel ? 'HOSTEL MONTHLY DUES' : 'HOUSE RENT DUES',
                        style: const TextStyle(
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
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_month, color: AppTheme.goldAccent, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      isHostel ? 'Hostel Rent Due Date' : 'House Rent Due Date',
                                      style: const TextStyle(
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
                            if (isHostel) ...[
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
                    const SizedBox(height: 16),

                    // Section: 100% Offline Local File Vault
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.folder_zip_outlined, color: AppTheme.primaryLight, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'LOCAL FILE VAULT',
                                      style: TextStyle(
                                        color: AppTheme.primaryLight,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    Text(
                                      '100% Offline • Auto-Mirrored to JSON',
                                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.greenAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(color: AppTheme.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'All memories are continuously mirrored to a local file (mindburst_vault.json). You can export an offline backup or restore memories anytime.',
                            style: TextStyle(color: AppTheme.textSecondary.withOpacity(0.9), fontSize: 11, height: 1.4),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.scaffoldBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Vault Storage: ${_vaultStats?.formattedSize ?? "Calculating..."}',
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${_vaultStats?.totalMemories ?? _totalMemories} Memories',
                                  style: const TextStyle(color: AppTheme.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _exportVault,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.file_download_outlined, size: 16),
                                  label: const Text('Export Backup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _restoreVault,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.textPrimary,
                                    side: const BorderSide(color: AppTheme.cardBorder),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.settings_backup_restore, size: 16),
                                  label: const Text('Restore File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

  Future<void> _exportVault() async {
    try {
      final file = await VaultStorageService.instance.exportVaultToFile();
      if (!mounted) return;
      await _loadProfileData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Offline Vault exported to:\n${file.path}'),
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _restoreVault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Restore from Local Vault?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'This will import memories saved in your local mindburst_vault.json file into the app without cloud dependence.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Memories'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final stats = await VaultStorageService.instance.getVaultStats();
        final count = await VaultStorageService.instance.importVaultFromFile(stats.filePath);
        if (!mounted) return;
        await _loadProfileData();
        widget.onProfileUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully restored $count memories from local vault!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildRoleCard(String roleKey, String title, String subtitle, IconData icon) {
    final isSelected = _profile.profession == roleKey;
    return InkWell(
      onTap: () => _updateProfession(roleKey),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.12) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textSecondary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
