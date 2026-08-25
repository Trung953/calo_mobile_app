import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_toast.dart';

class ExerciseSectionCard extends StatefulWidget {
  final ApiClient apiClient;
  final DateTime selectedDate;
  final VoidCallback onExerciseUpdated;

  const ExerciseSectionCard({
    super.key,
    required this.apiClient,
    required this.selectedDate,
    required this.onExerciseUpdated,
  });

  @override
  State<ExerciseSectionCard> createState() => _ExerciseSectionCardState();
}

class _ExerciseSectionCardState extends State<ExerciseSectionCard> {
  static final Map<String, List<Map<String, dynamic>>> _localExerciseHistory = {};

  int _burnedCalories = 0;
  List<dynamic> _exercises = [];

  @override
  void initState() {
    super.initState();
    _fetchExerciseLogs();
  }

  @override
  void didUpdateWidget(covariant ExerciseSectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _fetchExerciseLogs();
    }
  }

  String get _currentDateKey => DateFormat('yyyy-MM-dd').format(widget.selectedDate);

  Future<void> _fetchExerciseLogs() async {
    final dateStr = _currentDateKey;
    int apiBurned = 0;
    List<dynamic> apiList = [];

    try {
      final res = await widget.apiClient.get('${ApiEndpoints.diary}?date=$dateStr');
      final data = res['data'] ?? res;
      final summary = data['summary'] ?? {};
      apiBurned = (summary['totalBurnedCalories'] as num?)?.toInt() ??
          (summary['exerciseCaloriesBurned'] as num?)?.toInt() ??
          0;
      apiList = data['exercises'] ?? [];
    } catch (_) {}

    final localList = _localExerciseHistory[dateStr] ?? [];
    int localBurned = 0;
    for (var item in localList) {
      localBurned += (item['calories'] as num?)?.toInt() ?? 0;
    }

    if (mounted) {
      setState(() {
        _burnedCalories = apiBurned > localBurned ? apiBurned : (apiBurned + localBurned);
        _exercises = [...apiList, ...localList];
      });
    }
  }

  void _recalculateTotals() {
    final dateStr = _currentDateKey;
    final localList = _localExerciseHistory[dateStr] ?? [];
    int total = 0;
    for (var item in localList) {
      total += (item['calories'] as num?)?.toInt() ?? 0;
    }
    setState(() {
      _burnedCalories = total;
      _exercises = List.from(localList);
    });
    widget.onExerciseUpdated();
  }

  Future<void> _addOrUpdateExercise({
    required String name,
    required int calories,
    required int duration,
    int? editIndex,
  }) async {
    final dateStr = _currentDateKey;

    final exerciseItem = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'exerciseName': name,
      'calories': calories,
      'caloriesBurned': calories,
      'duration': duration,
      'durationMinutes': duration,
      'date': dateStr,
    };

    if (!_localExerciseHistory.containsKey(dateStr)) {
      _localExerciseHistory[dateStr] = [];
    }

    if (editIndex != null && editIndex < _localExerciseHistory[dateStr]!.length) {
      _localExerciseHistory[dateStr]![editIndex] = exerciseItem;
    } else {
      _localExerciseHistory[dateStr]!.add(exerciseItem);
    }

    _recalculateTotals();

    final payload = {
      'date': dateStr,
      'name': name,
      'exerciseName': name,
      'durationMin': duration,
      'durationMinutes': duration,
      'duration': duration,
      'caloriesBurned': calories,
      'calories': calories,
    };

    try {
      await widget.apiClient.post('${ApiEndpoints.diary}/exercise', payload);
    } catch (_) {
      try {
        await widget.apiClient.post('${ApiEndpoints.baseUrl}/exercises', payload);
      } catch (_) {}
    }
  }

  void _deleteExercise(int index) {
    final dateStr = _currentDateKey;
    if (_localExerciseHistory.containsKey(dateStr) && index < _localExerciseHistory[dateStr]!.length) {
      final removed = _localExerciseHistory[dateStr]!.removeAt(index);
      _recalculateTotals();
      AppToast.showSuccess(context, 'Đã xóa bài tập: ${removed['name']}');
    }
  }

  void _openExerciseModal({Map<String, dynamic>? initialData, int? editIndex}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: initialData?['name'] ?? '');
    final calCtrl = TextEditingController(text: initialData != null ? '${initialData['calories']}' : '');
    final durationCtrl = TextEditingController(text: initialData != null ? '${initialData['duration']}' : '30');

    final Color modalBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color inputFill = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: modalBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  editIndex == null ? 'Ghi nhận bài tập vận động' : 'Chỉnh sửa bài tập',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, color: subTextColor, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Tên hoạt động (vd: Chạy bộ, Gym, Đạp xe...)',
                labelStyle: GoogleFonts.plusJakartaSans(color: subTextColor, fontSize: 13),
                filled: true,
                fillColor: inputFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: durationCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Thời gian (phút)',
                      labelStyle: GoogleFonts.plusJakartaSans(color: subTextColor, fontSize: 13),
                      filled: true,
                      fillColor: inputFill,
                      suffixText: 'phút',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: calCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFF97316),
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Tiêu hao (kcal)',
                      labelStyle: GoogleFonts.plusJakartaSans(color: subTextColor, fontSize: 13),
                      filled: true,
                      fillColor: inputFill,
                      suffixText: 'kcal',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final cal = int.tryParse(calCtrl.text.trim()) ?? 0;
                  final duration = int.tryParse(durationCtrl.text.trim()) ?? 30;

                  if (name.isEmpty) {
                    AppToast.showError(context, 'Vui lòng nhập tên hoạt động', title: 'Thiếu thông tin');
                    return;
                  }

                  if (cal <= 0) {
                    AppToast.showError(context, 'Calo tiêu hao phải lớn hơn 0', title: 'Thông số không hợp lệ');
                    return;
                  }

                  Navigator.pop(ctx);
                  _addOrUpdateExercise(
                    name: name,
                    calories: cal,
                    duration: duration,
                    editIndex: editIndex,
                  );
                  AppToast.showSuccess(
                    context,
                    editIndex == null ? 'Đã thêm: "$name" (-$cal kcal)' : 'Đã cập nhật: "$name"',
                  );
                },
                child: Text(
                  editIndex == null ? 'Lưu Bài Tập' : 'Cập Nhật Bài Tập',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF161F30) : Colors.white;
    final Color innerItemBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color borderColor = isDark ? const Color(0xFF26354A) : const Color(0xFFE2E8F0);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề & Tổng calo đốt
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFF97316), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Tập Luyện & Vận Động',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    _burnedCalories > 0 ? '-$_burnedCalories' : '0',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _burnedCalories > 0 ? const Color(0xFFF97316) : subColor,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'kcal',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Số lượng & Nút ghi bài tập
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _exercises.isEmpty ? 'Chưa ghi nhận vận động' : '${_exercises.length} hoạt động hôm nay',
                style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              InkWell(
                onTap: () => _openExerciseModal(),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFFF97316)),
                      const SizedBox(width: 4),
                      Text(
                        'Ghi bài tập',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFF97316),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Danh sách bài tập đã ghi
          if (_exercises.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._exercises.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final name = item['name'] ?? item['exerciseName'] ?? 'Bài tập';
              final cal = item['calories'] ?? item['caloriesBurned'] ?? 0;
              final duration = item['duration'] ?? item['durationMinutes'] ?? 30;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: innerItemBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor.withValues(alpha: 0.7)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_run_rounded, color: Color(0xFFF97316), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$duration phút  •  -$cal kcal',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFF97316),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _openExerciseModal(
                          initialData: {
                            'name': name,
                            'calories': cal,
                            'duration': duration,
                          },
                          editIndex: index,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.edit_rounded, color: Color(0xFF0EA5E9), size: 15),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _deleteExercise(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 15),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 14),

          // Các nút thêm bài tập nhanh (Quick Chips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickChip(
                  icon: '🏃',
                  label: 'Chạy bộ (Vừa)',
                  isDark: isDark,
                  borderColor: borderColor,
                  textColor: textColor,
                  onTap: () {
                    _addOrUpdateExercise(name: 'Chạy bộ (Vừa)', calories: 200, duration: 20);
                    AppToast.showSuccess(context, 'Đã thêm nhanh "Chạy bộ (Vừa)" (-200 kcal)');
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickChip(
                  icon: '🏋️',
                  label: 'Tập Gym / Kháng lực',
                  isDark: isDark,
                  borderColor: borderColor,
                  textColor: textColor,
                  onTap: () {
                    _addOrUpdateExercise(name: 'Tập Gym / Kháng lực', calories: 150, duration: 45);
                    AppToast.showSuccess(context, 'Đã thêm nhanh "Tập Gym / Kháng lực" (-150 kcal)');
                  },
                ),
                const SizedBox(width: 8),
                _buildQuickChip(
                  icon: '🚴',
                  label: 'Đạp xe',
                  isDark: isDark,
                  borderColor: borderColor,
                  textColor: textColor,
                  onTap: () {
                    _addOrUpdateExercise(name: 'Đạp xe', calories: 180, duration: 30);
                    AppToast.showSuccess(context, 'Đã thêm nhanh "Đạp xe" (-180 kcal)');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip({
    required String icon,
    required String label,
    required bool isDark,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}