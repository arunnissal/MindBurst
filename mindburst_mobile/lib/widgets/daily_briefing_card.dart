import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/memory_model.dart';
import '../database/db_helper.dart';

class DailyBriefingCard extends StatefulWidget {
  final VoidCallback? onTap;

  const DailyBriefingCard({super.key, this.onTap});

  @override
  State<DailyBriefingCard> createState() => _DailyBriefingCardState();
}

class _DailyBriefingCardState extends State<DailyBriefingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  UserProfile _profile = UserProfile();
  int _pendingTaskCount = 0;
  int _habitCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _loadBriefingData();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadBriefingData() async {
    final profile = await DatabaseHelper.instance.getUserProfile();
    final tasks = await DatabaseHelper.instance.getActiveMemories(category: 'Tasks');
    final pending = tasks.where((t) => !t.completed).length;
    final routines = await DatabaseHelper.instance.getDailyRoutines(
      contextTag: profile.livingSituation,
    );
    final completedRoutines = routines.where((r) => r.isCompleted).length;

    if (mounted) {
      setState(() {
        _profile = profile;
        _pendingTaskCount = pending;
        _habitCount = routines.isEmpty ? 0 : (routines.length - completedRoutines);
        _isLoading = false;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning ☀️';
    if (hour >= 12 && hour < 17) return 'Good afternoon 🌤️';
    if (hour >= 17 && hour < 21) return 'Good evening ☕';
    return 'Night time 🌙';
  }

  String _getPersonaLabel() {
    String prof = 'Professional';
    if (_profile.profession == 'student') prof = 'Student';
    if (_profile.profession == 'homemaker') prof = 'Homemaker';
    if (_profile.profession == 'business') prof = 'Business';

    String living = 'Hostel';
    if (_profile.livingSituation == 'rented') living = 'Rented Home';
    if (_profile.livingSituation == 'home') living = 'Family Home';

    return '$prof • $living';
  }

  String? _getRentNotice() {
    if (_profile.livingSituation == 'home') return null;
    final now = DateTime.now();
    final dueDay = _profile.rentDueDay;
    if (dueDay < 1 || dueDay > 31) return null;

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final targetDay = dueDay > daysInMonth ? daysInMonth : dueDay;
    final diff = targetDay - now.day;

    if (diff == 0) return '⚠️ Rent due today!';
    if (diff == 1) return '📅 Rent due tomorrow!';
    if (diff > 1 && diff <= 5) return '📅 Rent due in $diff days';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();

    final greeting = _getGreeting();
    final persona = _getPersonaLabel();
    final rentNotice = _getRentNotice();

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowProgress = _glowController.value;
        return InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap?.call();
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Color.lerp(
                  AppTheme.cardBorder,
                  AppTheme.primary.withOpacity(0.4),
                  glowProgress,
                )!,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.04 + glowProgress * 0.05),
                  blurRadius: 12 + glowProgress * 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Animated pulse badge
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primary.withOpacity(0.12),
                        AppTheme.goldAccent.withOpacity(0.18),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppTheme.goldAccent,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),

                // Greeting & stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            greeting,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            persona,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (_pendingTaskCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$_pendingTaskCount tasks pending',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (_habitCount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.goldAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '🔥 $_habitCount habits left',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFB45309), // Amber-700
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (rentNotice != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.deleteRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                rentNotice,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.deleteRed,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
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
