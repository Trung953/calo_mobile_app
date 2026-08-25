import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/diary_entry_model.dart';

class FiberTrackerCard extends StatelessWidget {
  final List<DiaryEntryModel> meals;
  final double? targetCalories;
  final dynamic summary;

  const FiberTrackerCard({
    super.key,
    required this.meals,
    this.targetCalories,
    this.summary,
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
    // 1. Ưu tiên lấy trực tiếp calculatedFiber đã tính theo khẩu phần
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
    final Color barTrackColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0);
    const Color fiberColor = Color(0xFFA855F7);

    // Tính tổng chất xơ từ danh sách món ăn hoặc summary
    double totalFiber = 0.0;
    if (meals.isNotEmpty) {
      for (final meal in meals) {
        totalFiber += _extractFiberFromMeal(meal);
      }
    } else if (summary != null) {
      try {
        totalFiber = (summary.totalFiber as num?)?.toDouble() ?? 0.0;
      } catch (_) {}
    }

    double resolvedTargetCalories = 1977.0;
    if (targetCalories != null && targetCalories! > 0) {
      resolvedTargetCalories = targetCalories!;
    } else if (summary != null) {
      try {
        resolvedTargetCalories = (summary.targetCalories as num?)?.toDouble() ?? 1977.0;
      } catch (_) {}
    }

    final double calculatedTarget = ((resolvedTargetCalories / 1000.0) * 14.0).roundToDouble();
    final double progress = calculatedTarget > 0 ? (totalFiber / calculatedTarget).clamp(0.0, 1.0) : 0.0;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: fiberColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: fiberColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Chất Xơ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    totalFiber % 1 == 0 ? totalFiber.toInt().toString() : totalFiber.toStringAsFixed(1),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: fiberColor,
                    ),
                  ),
                  Text(
                    ' / ${calculatedTarget.toInt()}g',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: barTrackColor,
              valueColor: const AlwaysStoppedAnimation<Color>(fiberColor),
            ),
          ),
        ],
      ),
    );
  }
}