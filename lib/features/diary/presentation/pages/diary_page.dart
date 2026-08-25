import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/utils/app_toast.dart';
import '../../data/models/diary_entry_model.dart';
import '../bloc/diary_bloc.dart';
import '../bloc/diary_event.dart';
import '../bloc/diary_state.dart';
import '../widgets/calorie_summary_card.dart';
import '../widgets/edit_food_dialog.dart';
import '../widgets/meal_section_card.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../stats/presentation/pages/stats_page.dart';
import '../../../water/presentation/widgets/water_tracker_card.dart';
import '../../../exercise/presentation/widgets/exercise_section_card.dart';
import 'add_food_page.dart';
import 'ai_diet_plan_page.dart';
import '../widgets/fiber_tracker_card.dart';

class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  final GlobalKey<StatsPageState> _statsKey = GlobalKey<StatsPageState>();

  DateTime _selectedDate = DateTime.now();
  int _currentIndex = 0;
  String _userGoal = 'MAINTAIN';
  double _currentWeight = 65.0;
  double _targetWeight = 50.0;
  int _targetWaterMl = 2000;
  late final PageController _weekPageController;

  @override
  void initState() {
    super.initState();
    _weekPageController = PageController(initialPage: 0);
    _loadDiary();
    _fetchUserProfileGoal();
    
    // Tải trước dữ liệu thống kê ngầm sau khi màn hình dựng xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _statsKey.currentState?.loadAllData();
    });
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfileGoal() async {
    try {
      final apiClient = context.read<DiaryBloc>().repository.apiClient;
      final res = await apiClient.get(ApiEndpoints.profile);
      final raw = res['data'] ?? res;
      final profile = raw is Map ? (raw['profile'] ?? raw) : {};
      if (mounted && profile is Map) {
        final double weight = (profile['currentWeightKg'] as num?)?.toDouble() ??
            (profile['weight'] as num?)?.toDouble() ??
            65.0;

        final int calculatedWater = (profile['targetWaterMl'] as num?)?.toInt() ??
            (profile['targetWater'] as num?)?.toInt() ??
            ((weight * 35).round() ~/ 100 * 100).clamp(1500, 4000);

        setState(() {
          _userGoal = profile['goal'] ?? 'MAINTAIN';
          _currentWeight = weight;
          _targetWeight = (profile['targetWeightKg'] as num?)?.toDouble() ?? 50.0;
          _targetWaterMl = calculatedWater;
        });
      }
    } catch (_) {}
  }

  String _getAiRoadmapTitle() {
    if (_userGoal.contains('GAIN') || _targetWeight > _currentWeight + 0.1) {
      return 'AI Phân Tích & Lộ Trình Tăng Cân';
    } else if (_userGoal.contains('LOSE') || _targetWeight < _currentWeight - 0.1) {
      return 'AI Phân Tích & Lộ Trình Giảm Cân';
    }
    return 'AI Phân Tích & Lộ Trình Duy Trì Vóc Dáng';
  }

  void _loadDiary() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    context.read<DiaryBloc>().add(LoadDailyDiary(dateStr: dateStr));
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
    });
    _loadDiary();
  }

  List<DateTime> _getDaysOfWeek(int weeksAgo) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));
    final targetMonday = currentMonday.subtract(Duration(days: weeksAgo * 7));
    return List.generate(7, (i) => targetMonday.add(Duration(days: i)));
  }

  Future<void> _copyYesterdayMeal(String mealType) async {
    final apiClient = context.read<DiaryBloc>().repository.apiClient;
    final yesterday = _selectedDate.subtract(const Duration(days: 1));
    final fromDate = DateFormat('yyyy-MM-dd').format(yesterday);
    final toDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    try {
      await apiClient.post('${ApiEndpoints.diary}/copy-meal', {
        'fromDate': fromDate,
        'toDate': toDate,
        'mealType': mealType,
      });
      _loadDiary();
      if (!mounted) return;
      AppToast.showSuccess(context, 'Đã sao chép món ăn từ ngày hôm qua!');
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(
        context,
        'Không tìm thấy món ăn nào của bữa này ở hôm qua để sao chép.',
        title: 'Không thể sao chép',
      );
    }
  }

  void _confirmDelete(DiaryEntryModel log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Xác nhận xóa',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Bạn có chắc muốn xóa "${log.food?.name ?? "Món ăn"}" khỏi nhật ký?',
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
              context.read<DiaryBloc>().add(
                    DeleteDiaryEntryEvent(id: log.id, currentDate: dateStr),
                  );
              AppToast.showSuccess(context, 'Đã xóa món ăn khỏi nhật ký');
            },
            child: Text('Xóa', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openEditDialog(DiaryEntryModel log) {
    showDialog(
      context: context,
      builder: (ctx) => EditFoodDialog(
        entry: log,
        onUpdate: (mealType, quantity) async {
          final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
          context.read<DiaryBloc>().add(
                UpdateDiaryEntryEvent(
                  id: log.id,
                  currentDate: dateStr,
                  updates: {'mealType': mealType, 'quantity': quantity},
                ),
              );
          AppToast.showSuccess(context, 'Đã cập nhật món ăn thành công');
        },
      ),
    );
  }

  void _navigateToAddFood([String mealType = 'BREAKFAST']) async {
    final repo = context.read<DiaryBloc>().repository;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFoodPage(
          repository: repo,
          selectedDate: _selectedDate,
          defaultMealType: mealType,
        ),
      ),
    );

    if (result == true) {
      _loadDiary();
    }
  }

  Widget _buildHealthLogHeader(BuildContext context, dynamic apiClient, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF161F30) : Colors.white;
    final borderColor = isDark ? const Color(0xFF26354A) : const Color(0xFFE2E8F0);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isViewingOldDate = _selectedDate.year != today.year ||
        _selectedDate.month != today.month ||
        _selectedDate.day != today.day;
    final dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'HealthLog',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF10B981),
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              if (isViewingOldDate)
                GestureDetector(
                  onTap: () {
                    _onDateChanged(DateTime.now());
                    if (_weekPageController.hasClients) {
                      _weekPageController.animateToPage(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_toggle_off_rounded, color: Color(0xFF10B981), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Hôm nay',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: ProfilePage(apiClient: apiClient),
                      ),
                    ),
                  );
                  if (mounted) {
                    await _fetchUserProfileGoal();
                    _loadDiary();
                    _statsKey.currentState?.loadAllData();
                    setState(() {});
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.settings_outlined, color: subTextColor, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          SizedBox(
            height: 72,
            child: PageView.builder(
              controller: _weekPageController,
              reverse: true,
              itemBuilder: (context, weekIndex) {
                final weekDays = _getDaysOfWeek(weekIndex);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final dayDate = weekDays[index];
                    final isSelected = dayDate.year == _selectedDate.year &&
                        dayDate.month == _selectedDate.month &&
                        dayDate.day == _selectedDate.day;
                    final isToday = dayDate.year == today.year &&
                        dayDate.month == today.month &&
                        dayDate.day == today.day;
                    final isFuture = dayDate.isAfter(today);

                    return Expanded(
                      child: GestureDetector(
                        onTap: isFuture ? null : () => _onDateChanged(dayDate),
                        child: Opacity(
                          opacity: isFuture ? 0.3 : 1.0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    )
                                  : null,
                              color: isSelected
                                  ? null
                                  : (isDark ? const Color(0xFF161F30) : Colors.white),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : (isToday
                                        ? const Color(0xFF10B981).withValues(alpha: 0.6)
                                        : borderColor),
                                width: isToday && !isSelected ? 1.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  dayLabels[index],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : subTextColor,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${dayDate.day}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected
                                        ? Colors.white
                                        : textColor,
                                  ),
                                ),
                                if (isToday && !isSelected) ...[
                                  const SizedBox(height: 3),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryContent(BuildContext context, dynamic apiClient) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return BlocBuilder<DiaryBloc, DiaryState>(
      builder: (context, state) {
        return RefreshIndicator(
          color: const Color(0xFF10B981),
          onRefresh: () async {
            _loadDiary();
            await _fetchUserProfileGoal();
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHealthLogHeader(context, apiClient, isDark),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BANNER AI LỘ TRÌNH
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF064E3B), Color(0xFF0F2922), Color(0xFF13202E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AIDietPlanPage(apiClient: apiClient),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Color(0xFF34D399),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getAiRoadmapTitle(),
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Ước tính TDEE & gợi ý thực đơn 7 ngày',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Color(0xFF34D399),
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (state is DiaryLoading) ...[
                      const SizedBox(height: 40),
                      const Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
                    ] else if (state is DiaryError) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Column(
                            children: [
                              Text(state.message, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                onPressed: _loadDiary,
                                child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      )
                    ] else if (state is DiaryLoaded) ...[
                      CalorieSummaryCard(
                        summary: state.summary,
                        meals: state.meals,
                      ),
                      const SizedBox(height: 14),

                      WaterTrackerCard(
                        key: ValueKey('$_selectedDate-$_targetWaterMl'),
                        apiClient: apiClient,
                        selectedDate: _selectedDate,
                        targetWaterMl: _targetWaterMl,
                      ),
                      const SizedBox(height: 14),

                      FiberTrackerCard(
                        summary: state.summary,
                        meals: state.meals,
                        targetCalories: (state.summary.targetCalories as num?)?.toDouble(),
                      ),
                      const SizedBox(height: 14),

                      ExerciseSectionCard(
                        apiClient: apiClient,
                        selectedDate: _selectedDate,
                        onExerciseUpdated: _loadDiary,
                      ),
                      const SizedBox(height: 18),

                      Text(
                        'Nhật Ký Bữa Ăn',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      MealSectionCard(
                        title: 'Bữa sáng',
                        icon: '🌅',
                        mealType: 'BREAKFAST',
                        items: state.meals.where((m) => m.mealType == 'BREAKFAST').toList(),
                        onAddPressed: () => _navigateToAddFood('BREAKFAST'),
                        onCopyYesterdayPressed: () => _copyYesterdayMeal('BREAKFAST'),
                        onEditPressed: _openEditDialog,
                        onDeletePressed: _confirmDelete,
                      ),
                      MealSectionCard(
                        title: 'Bữa trưa',
                        icon: '☀️',
                        mealType: 'LUNCH',
                        items: state.meals.where((m) => m.mealType == 'LUNCH').toList(),
                        onAddPressed: () => _navigateToAddFood('LUNCH'),
                        onCopyYesterdayPressed: () => _copyYesterdayMeal('LUNCH'),
                        onEditPressed: _openEditDialog,
                        onDeletePressed: _confirmDelete,
                      ),
                      MealSectionCard(
                        title: 'Bữa tối',
                        icon: '🌙',
                        mealType: 'DINNER',
                        items: state.meals.where((m) => m.mealType == 'DINNER').toList(),
                        onAddPressed: () => _navigateToAddFood('DINNER'),
                        onCopyYesterdayPressed: () => _copyYesterdayMeal('DINNER'),
                        onEditPressed: _openEditDialog,
                        onDeletePressed: _confirmDelete,
                      ),
                      MealSectionCard(
                        title: 'Bữa phụ',
                        icon: '🍎',
                        mealType: 'SNACK',
                        items: state.meals.where((m) => m.mealType == 'SNACK').toList(),
                        onAddPressed: () => _navigateToAddFood('SNACK'),
                        onCopyYesterdayPressed: () => _copyYesterdayMeal('SNACK'),
                        onEditPressed: _openEditDialog,
                        onDeletePressed: _confirmDelete,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiClient = context.read<DiaryBloc>().repository.apiClient;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: [
                _buildDiaryContent(context, apiClient),
                StatsPage(key: _statsKey, apiClient: apiClient),
              ],
            ),

            // FLOATING DOCK BOTTOM NAVIGATION
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161F30) : Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: isDark ? const Color(0xFF26354A) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDockItem(
                      index: 0,
                      icon: Icons.book_outlined,
                      activeIcon: Icons.book_rounded,
                      label: 'Nhật ký',
                      isDark: isDark,
                      onTap: () {
                        setState(() => _currentIndex = 0);
                        _loadDiary();
                        _fetchUserProfileGoal();
                      },
                    ),
                    _buildDockItem(
                      index: 1,
                      icon: Icons.insights_outlined,
                      activeIcon: Icons.insights_rounded,
                      label: 'Thống kê',
                      isDark: isDark,
                      onTap: () {
                        setState(() => _currentIndex = 1);
                        _statsKey.currentState?.loadAllData();
                      },
                    ),
                    GestureDetector(
                      onTap: () => _navigateToAddFood('BREAKFAST'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              'Ghi món',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
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

  Widget _buildDockItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final bool isSelected = _currentIndex == index;
    const Color activeColor = Color(0xFF10B981);
    final Color inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}