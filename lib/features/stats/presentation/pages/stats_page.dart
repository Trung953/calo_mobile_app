import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/network/cache_manager.dart';

class StatsPage extends StatefulWidget {
  final ApiClient apiClient;

  const StatsPage({super.key, required this.apiClient});

  @override
  State<StatsPage> createState() => StatsPageState();
}

class StatsPageState extends State<StatsPage> {
  int _weekOffset = 0;
  bool _isLoading = false;

  // Cân nặng & Chiều cao
  double _heightCm = 170.0;
  double _currentWeight = 65.0;
  double _startWeight = 65.0;
  double _targetWeight = 50.0;
  double _weightChange = 0.0;

  // Dữ liệu 7 ngày (T2 -> CN)
  double _targetCalories = 1655.0;
  List<double> _weeklyCalories = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<double> _weeklyWater = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<double?> _weeklyWeights = [null, null, null, null, null, null, null];
  int _targetWater = 2000;

  final _weightInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  @override
  void dispose() {
    _weightInputController.dispose();
    super.dispose();
  }

  String _getWeekRangeLabel() {
    if (_weekOffset == 0) return 'Tuần này';
    final now = DateTime.now();
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    final targetMonday = currentMonday.subtract(Duration(days: _weekOffset * 7));
    final targetSunday = targetMonday.add(const Duration(days: 6));
    return 'thg ${targetMonday.month} ${targetMonday.day} - thg ${targetSunday.month} ${targetSunday.day}';
  }

  List<DateTime> _getDaysOfWeek() {
    final now = DateTime.now();
    final currentMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final targetMonday = currentMonday.subtract(Duration(days: _weekOffset * 7));
    return List.generate(7, (i) => targetMonday.add(Duration(days: i)));
  }
// Trong StatsPageState:
Future<void> loadAllData({bool forceRefresh = false, bool showToastOnError = false}) async {
  if (!mounted) return;

  final weekDays = _getDaysOfWeek();
  final cacheKey = 'stats_week_$_weekOffset';

  // 1. NẾU ĐÃ CÓ CACHE: Render ngay lập tức (0ms delay)
  final cached = FastCache.get(cacheKey);
  if (cached != null && !forceRefresh) {
    setState(() {
      _weeklyCalories = List<double>.from(cached['cals']);
      _weeklyWater = List<double>.from(cached['waters']);
      _weeklyWeights = List<double?>.from(cached['weights']);
      _heightCm = cached['height'] ?? _heightCm;
      _currentWeight = cached['weight'] ?? _currentWeight;
      _startWeight = cached['startW'] ?? _startWeight;
      _targetWeight = cached['targetW'] ?? _targetWeight;
      _targetCalories = cached['targetCal'] ?? _targetCalories;
      _targetWater = cached['targetWater'] ?? _targetWater;
      _weightChange = _currentWeight - _startWeight;
    });

    // Nếu cache còn mới, không cần gọi mạng
    if (!FastCache.isExpired(cacheKey)) return;
  }

  // 2. CHẠY PARALLEL REQUESTS NGẦM
  try {
    final profileFuture = widget.apiClient.get(ApiEndpoints.profile).catchError((_) => {});

    final diaryFutures = List.generate(7, (i) {
      final dateStr = DateFormat('yyyy-MM-dd').format(weekDays[i]);
      return widget.apiClient.get('${ApiEndpoints.diary}?date=$dateStr').catchError((_) => {});
    });

    final waterFutures = List.generate(7, (i) {
      final dateStr = DateFormat('yyyy-MM-dd').format(weekDays[i]);
      return widget.apiClient.get('${ApiEndpoints.water}?date=$dateStr').catchError((_) => {});
    });

    final results = await Future.wait([
      profileFuture,
      Future.wait(diaryFutures),
      Future.wait(waterFutures),
    ]);

    if (!mounted) return;

    // Parse profile
    final profileRes = results[0] as dynamic;
    final raw = profileRes['data'] ?? profileRes;
    final profile = raw is Map ? (raw['profile'] ?? raw) : {};

    double height = _heightCm;
    double weight = _currentWeight;
    double startW = _startWeight;
    double targetW = _targetWeight;
    double targetCal = _targetCalories;
    int targetWater = _targetWater;

    if (profile is Map && profile.isNotEmpty) {
      weight = (profile['currentWeightKg'] as num?)?.toDouble() ??
          (profile['weight'] as num?)?.toDouble() ?? _currentWeight;
      height = (profile['heightCm'] as num?)?.toDouble() ?? _heightCm;
      startW = (profile['startWeightKg'] as num?)?.toDouble() ?? _startWeight;
      targetW = (profile['targetWeightKg'] as num?)?.toDouble() ?? _targetWeight;
      targetCal = (profile['targetCalories'] as num?)?.toDouble() ?? _targetCalories;
      targetWater = (profile['targetWaterMl'] as num?)?.toInt() ?? _targetWater;
    }

    final diaryResults = results[1] as List<dynamic>;
    final waterResults = results[2] as List<dynamic>;

    final List<double> cals = List.filled(7, 0.0);
    final List<double> waters = List.filled(7, 0.0);
    final List<double?> weights = List.filled(7, null);

    for (int i = 0; i < 7; i++) {
      final dRaw = diaryResults[i] is Map ? (diaryResults[i]['data'] ?? diaryResults[i]) : null;
      if (dRaw is Map) {
        final summary = dRaw['summary'] ?? dRaw['caloriesSummary'] ?? dRaw;
        cals[i] = (summary['totalCalories'] as num?)?.toDouble() ??
            (summary['consumedCalories'] as num?)?.toDouble() ?? 0.0;
      }

      final wRaw = waterResults[i] is Map ? (waterResults[i]['data'] ?? waterResults[i]) : null;
      if (wRaw is Map) {
        waters[i] = (wRaw['totalAmountMl'] as num?)?.toDouble() ??
            (wRaw['amountMl'] as num?)?.toDouble() ?? 0.0;
      }
    }

    if (_weekOffset == 0) {
      final todayIdx = DateTime.now().weekday - 1;
      if (todayIdx >= 0 && todayIdx < 7) weights[todayIdx] = weight;
    }

    // Lưu vào Cache
    FastCache.set(cacheKey, {
      'cals': cals,
      'waters': waters,
      'weights': weights,
      'height': height,
      'weight': weight,
      'startW': startW,
      'targetW': targetW,
      'targetCal': targetCal,
      'targetWater': targetWater,
    });

    setState(() {
      _heightCm = height;
      _currentWeight = weight;
      _startWeight = startW;
      _targetWeight = targetW;
      _targetCalories = targetCal;
      _targetWater = targetWater;
      _weightChange = weight - startW;
      _weeklyCalories = cals;
      _weeklyWater = waters;
      _weeklyWeights = weights;
    });
  } catch (_) {
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  Future<void> _logNewWeight() async {
    final val = double.tryParse(_weightInputController.text);
    if (val == null || val <= 0) {
      AppToast.showError(context, 'Vui lòng nhập cân nặng hợp lệ', title: 'Lỗi nhập liệu');
      return;
    }

    try {
      await widget.apiClient.put(ApiEndpoints.profile, {
        'currentWeightKg': val,
        'weight': val,
        'targetWeightKg': _targetWeight,
        'targetWeight': _targetWeight,
      });

      try {
        await widget.apiClient.post('${ApiEndpoints.profile}/weight', {
          'weight': val,
          'weightKg': val,
          'date': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      if (!mounted) return;
      AppToast.showSuccess(
        context,
        'Đã cập nhật cân nặng: ${val.toStringAsFixed(1)} kg',
        title: 'Thành công',
      );

      _weightInputController.clear();
      setState(() {
        _currentWeight = val;
        _weightChange = _currentWeight - _startWeight;
        _targetWater = ((val * 35).round() ~/ 100 * 100).clamp(1500, 4000);
        final currentWeekday = DateTime.now().weekday - 1;
        if (currentWeekday >= 0 && currentWeekday < 7) {
          _weeklyWeights[currentWeekday] = val;
        }
      });
      loadAllData();
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e, title: 'Không thể lưu cân nặng');
    }
  }

  void _showAddWeightDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color inputFill = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.monitor_weight_outlined, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Ghi nhận cân nặng',
              style: GoogleFonts.plusJakartaSans(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: _weightInputController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: GoogleFonts.plusJakartaSans(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
          decoration: InputDecoration(
            hintText: 'VD: ${_currentWeight.toStringAsFixed(1)}',
            hintStyle: GoogleFonts.plusJakartaSans(color: subTextColor, fontSize: 14),
            suffixText: 'kg',
            suffixStyle: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF10B981),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
            filled: true,
            fillColor: inputFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Hủy', style: GoogleFonts.plusJakartaSans(color: subTextColor, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _logNewWeight();
            },
            child: Text('Xác nhận', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF161F30) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF26354A) : const Color(0xFFE2E8F0);
    const primaryColor = Color(0xFF10B981);

    // Tiến trình %
    double goalProgress = 0.0;
    final totalDiff = (_startWeight - _targetWeight).abs();
    if (totalDiff > 0.05) {
      final currentProgressDiff = (_startWeight - _currentWeight).abs();
      goalProgress = (currentProgressDiff / totalDiff).clamp(0.0, 1.0);
    }

    // BMI
    final heightM = _heightCm / 100.0;
    final bmi = _currentWeight / (heightM * heightM);
    String bmiClassification = 'Bình thường';
    Color bmiColor = const Color(0xFF10B981);
    if (bmi < 18.5) {
      bmiClassification = 'Thiếu cân';
      bmiColor = const Color(0xFF38BDF8);
    } else if (bmi >= 23 && bmi < 24.9) {
      bmiClassification = 'Tiền thừa cân';
      bmiColor = const Color(0xFFFBBF24);
    } else if (bmi >= 25) {
      bmiClassification = 'Thừa cân / Béo phì';
      bmiColor = const Color(0xFFEF4444);
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryColor))
            : RefreshIndicator(
                color: primaryColor,
                onRefresh: () => loadAllData(showToastOnError: true),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
                  children: [
                    // 1. HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tiến trình',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: primaryColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getWeekRangeLabel(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: subTextColor,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.chevron_left_rounded, color: textColor, size: 24),
                                onPressed: () {
                                  setState(() => _weekOffset++);
                                  loadAllData();
                                },
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.chevron_right_rounded,
                                  color: _weekOffset > 0 ? textColor : subTextColor.withValues(alpha: 0.3),
                                  size: 24,
                                ),
                                onPressed: _weekOffset > 0
                                    ? () {
                                        setState(() => _weekOffset--);
                                        loadAllData();
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 2. THẺ TIẾN TRÌNH CÂN NẶNG
                    Container(
                      padding: const EdgeInsets.all(20),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'THAY ĐỔI',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: subTextColor,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_weightChange >= 0 ? "+" : ""}${_weightChange.toStringAsFixed(1)} kg',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'CÂN NẶNG HIỆN TẠI',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: subTextColor,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_currentWeight.toStringAsFixed(1)} kg',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'MỤC TIÊU TIẾN ĐỘ',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: subTextColor,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                '${(goalProgress * 100).toInt()}%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              height: 22,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: CustomPaint(
                                painter: _StripedProgressPainter(
                                  progress: goalProgress,
                                  activeColor: const Color(0xFF10B981),
                                  stripeColor: Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_startWeight.toStringAsFixed(1)} kg',
                                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: subTextColor),
                              ),
                              Row(
                                children: [
                                  Icon(Icons.flag_rounded, color: primaryColor, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Mục tiêu: ${_targetWeight.toStringAsFixed(1)} kg',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: primaryColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. BIỂU ĐỒ CÂN NẶNG TUẦN
                    Container(
                      padding: const EdgeInsets.all(20),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tiến trình cân nặng (kg)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                              GestureDetector(
                                onTap: _showAddWeightDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.add_rounded, color: primaryColor, size: 15),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Ghi kg',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          SizedBox(
                            height: 160,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                size: const Size(double.infinity, 160),
                                painter: _WeightDynamicChartPainter(
                                  targetWeight: _targetWeight,
                                  weeklyWeights: _weeklyWeights,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 14, height: 2, color: const Color(0xFFEF4444)),
                              const SizedBox(width: 6),
                              Text(
                                'Mục tiêu cân nặng (${_targetWeight.toStringAsFixed(1)} kg)',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: subTextColor, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. BIỂU ĐỒ NĂNG LƯỢNG CALO
                    Container(
                      padding: const EdgeInsets.all(20),
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Tiến trình năng lượng',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Mục tiêu: ${_targetCalories.round()} kcal',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          SizedBox(
                            height: 160,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                size: const Size(double.infinity, 160),
                                painter: _CalorieChartPainter(
                                  targetCalories: _targetCalories,
                                  dailyCalories: _weeklyCalories,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 14, height: 2, color: const Color(0xFFEF4444)),
                              const SizedBox(width: 6),
                              Text(
                                'Mục tiêu năng lượng (${_targetCalories.round()} kcal)',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: subTextColor, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. BIỂU ĐỒ LƯỢNG NƯỚC (ML)
                    Container(
                      padding: const EdgeInsets.all(20),
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.water_drop_rounded, color: Color(0xFF38BDF8), size: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tiến trình lượng nước',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Mục tiêu: $_targetWater ml',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF38BDF8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          SizedBox(
                            height: 160,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                size: const Size(double.infinity, 160),
                                painter: _WaterChartPainter(
                                  targetWater: _targetWater.toDouble(),
                                  dailyWater: _weeklyWater,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 14, height: 2, color: const Color(0xFF38BDF8)),
                              const SizedBox(width: 6),
                              Text(
                                'Mục tiêu nước uống ($_targetWater ml)',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: subTextColor, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 6. THẺ CHỈ SỐ BMI
                    Container(
                      padding: const EdgeInsets.all(20),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Chỉ số BMI của bạn',
                                style: GoogleFonts.plusJakartaSans(fontSize: 15.5, fontWeight: FontWeight.w800, color: textColor),
                              ),
                              Icon(Icons.info_outline_rounded, color: subTextColor, size: 18),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                bmi.toStringAsFixed(1),
                                style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, color: textColor),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: bmiColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: bmiColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  bmiClassification,
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: bmiColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final w = constraints.maxWidth;
                              final double markerPercent = ((bmi - 15.0) / (35.0 - 15.0)).clamp(0.02, 0.98);

                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 35, child: Container(height: 8, color: const Color(0xFF38BDF8))),
                                        const SizedBox(width: 2),
                                        Expanded(flex: 65, child: Container(height: 8, color: const Color(0xFF10B981))),
                                        const SizedBox(width: 2),
                                        Expanded(flex: 50, child: Container(height: 8, color: const Color(0xFFFBBF24))),
                                        const SizedBox(width: 2),
                                        Expanded(flex: 50, child: Container(height: 8, color: const Color(0xFFEF4444))),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    left: w * markerPercent - 3,
                                    top: -4,
                                    child: Container(
                                      width: 6,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: textColor,
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildBmiLegend('Thiếu cân', '<18.5', const Color(0xFF38BDF8), subTextColor, textColor),
                              _buildBmiLegend('Khỏe mạnh', '18.5–24.9', const Color(0xFF10B981), subTextColor, textColor),
                              _buildBmiLegend('Thừa cân', '25.0–29.9', const Color(0xFFFBBF24), subTextColor, textColor),
                              _buildBmiLegend('Béo phì', '>30.0', const Color(0xFFEF4444), subTextColor, textColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBmiLegend(String label, String range, Color color, Color subTextColor, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: subTextColor, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(range, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: textColor, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// CUSTOM PAINTERS
// -------------------------------------------------------------
class _WeightDynamicChartPainter extends CustomPainter {
  final double targetWeight;
  final List<double?> weeklyWeights;
  final bool isDark;

  _WeightDynamicChartPainter({
    required this.targetWeight,
    required this.weeklyWeights,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    final textStyle = GoogleFonts.plusJakartaSans(
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
    );

    final validWeights = weeklyWeights.whereType<double>().toList();
    final allValues = [...validWeights, targetWeight];
    double maxW = allValues.reduce((a, b) => a > b ? a : b) + 2.0;
    double minW = allValues.reduce((a, b) => a < b ? a : b) - 2.0;
    if (maxW - minW < 4.0) {
      maxW += 2.0;
      minW -= 2.0;
    }
    final stepVal = (maxW - minW) / 4.0;

    final labels = List.generate(5, (i) => (maxW - i * stepVal).round().toString());
    final yStep = (size.height - 20) / (labels.length - 1);

    for (int i = 0; i < labels.length; i++) {
      textPainter.text = TextSpan(text: labels[i], style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, i * yStep - 6));
    }

    const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final xStart = 32.0;
    final xStep = (size.width - xStart) / (days.length - 1);

    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF26354A).withValues(alpha: 0.5) : const Color(0xFFE2E8F0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < days.length; i++) {
      final x = xStart + i * xStep;
      for (double y = 0; y < size.height - 20; y += 8) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 4), gridPaint);
      }
      textPainter.text = TextSpan(text: days[i], style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - 12));
    }

    final targetY = ((maxW - targetWeight) / (maxW - minW) * (size.height - 20)).clamp(0.0, size.height - 20);
    final targetPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 1.5;

    for (double x = xStart; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, targetY), Offset(x + 5, targetY), targetPaint);
    }

    final linePaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..color = const Color(0xFF10B981);
    final dotWhite = Paint()..color = Colors.white;

    Offset? lastPoint;
    for (int i = 0; i < weeklyWeights.length && i < 7; i++) {
      final w = weeklyWeights[i];
      if (w != null) {
        final x = xStart + i * xStep;
        final y = ((maxW - w) / (maxW - minW) * (size.height - 20)).clamp(0.0, size.height - 20);
        final currentPoint = Offset(x, y);

        if (lastPoint != null) {
          canvas.drawLine(lastPoint, currentPoint, linePaint);
        }
        lastPoint = currentPoint;

        canvas.drawCircle(currentPoint, 5.5, dotPaint);
        canvas.drawCircle(currentPoint, 2.5, dotWhite);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WeightDynamicChartPainter oldDelegate) => true;
}

class _StripedProgressPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color stripeColor;

  _StripedProgressPainter({
    required this.progress,
    required this.activeColor,
    required this.stripeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final activeWidth = size.width * progress;
    final bgPaint = Paint()..color = activeColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, activeWidth, size.height), const Radius.circular(14)),
      bgPaint,
    );

    final stripePaint = Paint()
      ..color = stripeColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const step = 8.0;
    for (double x = -size.height; x < activeWidth; x += step) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), stripePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StripedProgressPainter oldDelegate) => oldDelegate.progress != progress;
}

class _CalorieChartPainter extends CustomPainter {
  final double targetCalories;
  final List<double> dailyCalories;
  final bool isDark;

  _CalorieChartPainter({
    required this.targetCalories,
    required this.dailyCalories,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    final textStyle = GoogleFonts.plusJakartaSans(
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    final maxCal = (targetCalories * 1.3).clamp(1800.0, 3000.0);
    final labels = [
      maxCal.round().toString(),
      (maxCal * 0.75).round().toString(),
      (maxCal * 0.5).round().toString(),
      (maxCal * 0.25).round().toString(),
      '0',
    ];
    final yStep = (size.height - 20) / (labels.length - 1);

    for (int i = 0; i < labels.length; i++) {
      textPainter.text = TextSpan(text: labels[i], style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, i * yStep - 6));
    }

    const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final xStart = 34.0;
    final xStep = (size.width - xStart) / (days.length - 1);

    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF26354A).withValues(alpha: 0.5) : const Color(0xFFE2E8F0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < days.length; i++) {
      final x = xStart + i * xStep;
      for (double y = 0; y < size.height - 20; y += 8) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 4), gridPaint);
      }
      textPainter.text = TextSpan(text: days[i], style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - 12));
    }

    final targetY = ((maxCal - targetCalories) / maxCal * (size.height - 20)).clamp(0.0, size.height - 20);
    final targetPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 1.5;

    for (double x = xStart; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, targetY), Offset(x + 5, targetY), targetPaint);
    }

    // Vẽ cột năng lượng calo thực tế
    final barPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;

    for (int i = 0; i < dailyCalories.length && i < 7; i++) {
      final cal = dailyCalories[i];
      if (cal <= 0) continue;
      final x = xStart + i * xStep;
      final calHeight = (cal / maxCal * (size.height - 20)).clamp(4.0, size.height - 20);
      final y = (size.height - 20) - calHeight;
      canvas.drawLine(Offset(x, size.height - 20), Offset(x, y), barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CalorieChartPainter oldDelegate) => true;
}

class _WaterChartPainter extends CustomPainter {
  final double targetWater;
  final List<double> dailyWater;
  final bool isDark;

  _WaterChartPainter({
    required this.targetWater,
    required this.dailyWater,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    final textStyle = GoogleFonts.plusJakartaSans(
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );

    final maxWater = (targetWater * 1.25).clamp(2000.0, 3500.0);
    final labels = [
      maxWater.round().toString(),
      (maxWater * 0.75).round().toString(),
      (maxWater * 0.5).round().toString(),
      (maxWater * 0.25).round().toString(),
      '0',
    ];
    final yStep = (size.height - 20) / (labels.length - 1);

    for (int i = 0; i < labels.length; i++) {
      textPainter.text = TextSpan(text: labels[i], style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, i * yStep - 6));
    }

    const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final xStart = 34.0;
    final xStep = (size.width - xStart) / (days.length - 1);

    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF26354A).withValues(alpha: 0.5) : const Color(0xFFE2E8F0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < days.length; i++) {
      final x = xStart + i * xStep;
      for (double y = 0; y < size.height - 20; y += 8) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 4), gridPaint);
      }
      textPainter.text = TextSpan(text: days[i], style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - 12));
    }

    final targetY = ((maxWater - targetWater) / maxWater * (size.height - 20)).clamp(0.0, size.height - 20);
    final targetPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 1.5;

    for (double x = xStart; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, targetY), Offset(x + 5, targetY), targetPaint);
    }

    // Vẽ cột lượng nước thực tế
    final barPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;

    for (int i = 0; i < dailyWater.length && i < 7; i++) {
      final w = dailyWater[i];
      if (w <= 0) continue;
      final x = xStart + i * xStep;
      final calculatedHeight = (w / maxWater * (size.height - 20));
      final wHeight = calculatedHeight.clamp(16.0, size.height - 20);
      final y = (size.height - 20) - wHeight;
      canvas.drawLine(Offset(x, size.height - 20), Offset(x, y), barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaterChartPainter oldDelegate) => true;
}