import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/diary_entry_model.dart';

class CalorieSummaryCard extends StatelessWidget {
  final dynamic summary;
  final List<DiaryEntryModel>? meals;

  const CalorieSummaryCard({
    super.key,
    required this.summary,
    this.meals,
  });

  static double _parseNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(val);
      if (match != null) {
        return double.tryParse(match.group(1)!) ?? 0.0;
      }
    }
    return 0.0;
  }

  static double _extractFiberFromMeal(DiaryEntryModel meal) {
    // 1. ƯU TIÊN SỐ 1: Lấy trực tiếp calculatedFiber đã tính theo khẩu phần
    try {
      dynamic m = meal;
      final calc = _parseNum(m.calculatedFiber);
      if (calc > 0) return calc;
    } catch (_) {}

    final food = meal.food;
    if (food == null) return 0.0;

    // 2. Lấy từ JSON description gốc nếu có
    final desc = food.description ?? '';
    if (desc.isNotEmpty && (desc.startsWith('{') || desc.startsWith('['))) {
      try {
        final decoded = jsonDecode(desc);
        if (decoded is Map<String, dynamic>) {
          final f = _parseNum(
            decoded['totalFiber'] ??
            decoded['fiberG'] ??
            decoded['fiber'] ??
            decoded['dietaryFiber'],
          );
          if (f > 0) return f;
        }
      } catch (_) {}
    }

    // 3. Nhân theo tỉ lệ khối lượng thực tế
    if (food.fiberG > 0) {
      final double qty = (meal.quantity as num?)?.toDouble() ?? 100.0;
      final double servingWeight = (food.servingSizeWeight as num?)?.toDouble() ?? 100.0;
      final double mult = servingWeight > 0 ? (qty / servingWeight) : 1.0;
      return food.fiberG * mult;
    }

    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF161F30) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color borderColor = isDark ? const Color(0xFF26354A) : const Color(0xFFE2E8F0);

    final double targetCal = (summary.targetCalories as num?)?.toDouble() ?? 1977.0;
    final double targetCarbs = (targetCal * 0.50) / 4.0;
    final double targetProtein = (targetCal * 0.25) / 4.0;
    final double targetFat = (targetCal * 0.25) / 9.0;
    final double targetFiber = (targetCal / 1000.0) * 14.0;

    double currentCalories = 0.0;
    double currentCarbs = 0.0;
    double currentProtein = 0.0;
    double currentFat = 0.0;
    double currentFiber = 0.0;

    if (meals != null && meals!.isNotEmpty) {
      for (final m in meals!) {
        currentCalories += (m.calculatedCalories > 0 ? m.calculatedCalories : (m.food?.calories ?? 0));
        currentCarbs += (m.calculatedCarbs > 0 ? m.calculatedCarbs.toDouble() : (m.food?.carbsG ?? 0.0));
        currentProtein += (m.calculatedProtein > 0 ? m.calculatedProtein.toDouble() : (m.food?.proteinG ?? 0.0));
        currentFat += (m.calculatedFat > 0 ? m.calculatedFat.toDouble() : (m.food?.fatG ?? 0.0));
        currentFiber += _extractFiberFromMeal(m);
      }
    } else {
      currentCalories = (summary.totalCalories as num?)?.toDouble() ?? 0.0;
      currentCarbs = (summary.totalCarbs as num?)?.toDouble() ?? 0.0;
      currentProtein = (summary.totalProtein as num?)?.toDouble() ?? 0.0;
      currentFat = (summary.totalFat as num?)?.toDouble() ?? 0.0;
      currentFiber = (summary.totalFiber as num?)?.toDouble() ?? 0.0;
    }

    final int remaining = targetCal.round() - currentCalories.round();
    final bool isExceeded = remaining < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TIÊU ĐỀ + BADGE TRẠNG THÁI CALO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NĂNG LƯỢNG HÔM NAY',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: subTextColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isExceeded
                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                      : const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isExceeded
                        ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                        : const Color(0xFF10B981).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  !isExceeded ? 'Còn lại $remaining kcal' : 'Vượt ${-remaining} kcal',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isExceeded ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. TỔNG CALO TIÊU THỤ TRÊN MỤC TIÊU
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${currentCalories.round()}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: -0.8,
                ),
              ),
              Text(
                ' / ${targetCal.round()} kcal',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: subTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3. DANH SÁCH 4 MACRO + VÒNG CUNG NĂNG LƯỢNG
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cột bên trái: 4 chỉ số Macro
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMacroRow(
                      icon: Icons.grain_rounded,
                      color: const Color(0xFF0EA5E9), // Carbs
                      label: 'CARBS',
                      current: currentCarbs,
                      target: targetCarbs,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    const SizedBox(height: 12),
                    _buildMacroRow(
                      icon: Icons.fitness_center_rounded,
                      color: const Color(0xFF10B981), // Protein
                      label: 'PROTEIN',
                      current: currentProtein,
                      target: targetProtein,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    const SizedBox(height: 12),
                    _buildMacroRow(
                      icon: Icons.egg_alt_rounded, // Fat (Đã đổi icon)
                      color: const Color(0xFFF59E0B),
                      label: 'FAT',
                      current: currentFat,
                      target: targetFat,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                    const SizedBox(height: 12),
                    _buildMacroRow(
                      icon: Icons.eco_rounded, // Chất xơ
                      color: const Color(0xFFA855F7),
                      label: 'CHẤT XƠ',
                      current: currentFiber,
                      target: targetFiber,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Cột bên phải: 4 Vòng cung tròn
              SizedBox(
                width: 145,
                height: 145,
                child: CustomPaint(
                  painter: _MacroCirclePainter(
                    carbProgress: targetCarbs > 0 ? (currentCarbs / targetCarbs).clamp(0.0, 1.0) : 0.0,
                    proteinProgress: targetProtein > 0 ? (currentProtein / targetProtein).clamp(0.0, 1.0) : 0.0,
                    fatProgress: targetFat > 0 ? (currentFat / targetFat).clamp(0.0, 1.0) : 0.0,
                    fiberProgress: targetFiber > 0 ? (currentFiber / targetFiber).clamp(0.0, 1.0) : 0.0,
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow({
    required IconData icon,
    required Color color,
    required String label,
    required double current,
    required double target,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${current % 1 == 0 ? current.toInt() : current.toStringAsFixed(1)}g',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              Text(
                '$label (${target.round()}g)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: subTextColor,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// VẼ 4 VÒNG CUNG TIẾN ĐỘ NĂNG LƯỢNG NGUYÊN BẢN
// -------------------------------------------------------------
class _MacroCirclePainter extends CustomPainter {
  final double carbProgress;
  final double proteinProgress;
  final double fatProgress;
  final double fiberProgress;
  final bool isDark;

  _MacroCirclePainter({
    required this.carbProgress,
    required this.proteinProgress,
    required this.fatProgress,
    required this.fiberProgress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 8.0;

    _drawArc(canvas, center, 62, strokeWidth, const Color(0xFF0EA5E9), carbProgress);
    _drawArc(canvas, center, 49, strokeWidth, const Color(0xFF10B981), proteinProgress);
    _drawArc(canvas, center, 36, strokeWidth, const Color(0xFFF59E0B), fatProgress);
    _drawArc(canvas, center, 23, strokeWidth, const Color(0xFFA855F7), fiberProgress);
  }

  void _drawArc(
    Canvas canvas,
    Offset center,
    double radius,
    double strokeWidth,
    Color activeColor,
    double progress,
  ) {
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = isDark ? const Color(0xFF26354A).withValues(alpha: 0.5) : const Color(0xFFE2E8F0);

    const startAngle = -math.pi * 0.85;
    final sweepAngle = math.pi * 1.35;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepAngle, false, bgPaint);

    if (progress > 0) {
      final activePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = activeColor;

      final currentSweep = sweepAngle * progress;
      canvas.drawArc(rect, startAngle, currentSweep, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MacroCirclePainter oldDelegate) {
    return oldDelegate.carbProgress != carbProgress ||
        oldDelegate.proteinProgress != proteinProgress ||
        oldDelegate.fatProgress != fatProgress ||
        oldDelegate.fiberProgress != fiberProgress ||
        oldDelegate.isDark != isDark;
  }
}