import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/models/diary_entry_model.dart';
import '../../data/models/food_model.dart';

class FoodLogDialog extends StatefulWidget {
  final FoodModel food;
  final String initialMealType;
  final DateTime selectedDate;
  final Future<void> Function(DiaryEntryModel entry) onSave;

  const FoodLogDialog({
    super.key,
    required this.food,
    this.initialMealType = 'BREAKFAST',
    required this.selectedDate,
    required this.onSave,
  });

  @override
  State<FoodLogDialog> createState() => _FoodLogDialogState();
}

class _FoodLogDialogState extends State<FoodLogDialog> {
  late TextEditingController _weightCtrl;
  late String _selectedMealType;
  bool _isSaving = false;

  late double _baseCal;
  late double _baseCarbs;
  late double _baseProtein;
  late double _baseFat;
  late double _baseFiber;
  late double _baseServing;

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.initialMealType;

    // Đọc trực tiếp từ các trường của FoodModel (không dùng dynamic)
    _baseCal = widget.food.calories.toDouble();
    _baseCarbs = widget.food.carbsG;
    _baseProtein = widget.food.proteinG;
    _baseFat = widget.food.fatG;
    _baseFiber = widget.food.fiberG;

    final rawServing = widget.food.servingSizeWeight ?? 100.0;
    _baseServing = rawServing > 0 ? rawServing : 100.0;

    _weightCtrl = TextEditingController(text: _baseServing.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  String _getMealName(String type) {
    switch (type) {
      case 'BREAKFAST': return 'Bữa sáng';
      case 'LUNCH': return 'Bữa trưa';
      case 'DINNER': return 'Bữa tối';
      case 'SNACK': return 'Bữa phụ';
      default: return 'Bữa ăn';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color subBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final double inputGrams = double.tryParse(_weightCtrl.text) ?? 0.0;
    final double ratio = _baseServing > 0 ? (inputGrams / _baseServing) : 1.0;

    final int calcCal = (_baseCal * ratio).round();
    final double calcCarbs = _baseCarbs * ratio;
    final double calcProtein = _baseProtein * ratio;
    final double calcFat = _baseFat * ratio;
    final double calcFiber = _baseFiber * ratio;

    return Dialog(
      backgroundColor: bg,
      elevation: 24,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ghi nhận món ăn',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF10B981),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.food.name,
                        style: GoogleFonts.plusJakartaSans(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, color: subTextColor, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Text(
              'Chọn bữa ăn',
              style: GoogleFonts.plusJakartaSans(color: subTextColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMealChip('BREAKFAST', '🌅 Sáng', isDark),
                const SizedBox(width: 6),
                _buildMealChip('LUNCH', '☀️ Trưa', isDark),
                const SizedBox(width: 6),
                _buildMealChip('DINNER', '🌙 Tối', isDark),
                const SizedBox(width: 6),
                _buildMealChip('SNACK', '🍎 Phụ', isDark),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: subBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.w900, fontSize: 18),
                      decoration: InputDecoration(
                        labelText: 'Khối lượng định lượng',
                        labelStyle: GoogleFonts.plusJakartaSans(color: subTextColor, fontSize: 12.5),
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.food.servingSizeUnit ?? 'g',
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: subBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tổng Năng Lượng',
                        style: GoogleFonts.plusJakartaSans(color: subTextColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$calcCal',
                            style: GoogleFonts.plusJakartaSans(
                              color: textColor,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'kcal',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF10B981),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: borderColor, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildMacroItem('Carbs', '${calcCarbs.toStringAsFixed(1)}g', const Color(0xFFF59E0B), isDark),
                      const SizedBox(width: 6),
                      _buildMacroItem('Đạm', '${calcProtein.toStringAsFixed(1)}g', const Color(0xFF0EA5E9), isDark),
                      const SizedBox(width: 6),
                      _buildMacroItem('Béo', '${calcFat.toStringAsFixed(1)}g', const Color(0xFFEC4899), isDark),
                      const SizedBox(width: 6),
                      _buildMacroItem('Xơ', '${calcFiber.toStringAsFixed(1)}g', const Color(0xFFA855F7), isDark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (inputGrams <= 0) return;
                        setState(() => _isSaving = true);

                        final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
                        final entry = DiaryEntryModel(
                          id: '',
                          foodId: widget.food.id,
                          mealType: _selectedMealType,
                          quantity: inputGrams,
                          date: dateStr,
                          calculatedCalories: calcCal,
                          calculatedCarbs: calcCarbs,
                          calculatedProtein: calcProtein,
                          calculatedFat: calcFat,
                          calculatedFiber: calcFiber,
                          food: widget.food,
                        );

                        try {
                          await widget.onSave(entry);
                          if (!mounted) return;
                          Navigator.pop(context, true);
                        } catch (_) {
                          if (mounted) setState(() => _isSaving = false);
                        }
                      },
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        'LƯU VÀO ${_getMealName(_selectedMealType).toUpperCase()}',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealChip(String type, String label, bool isDark) {
    final isSelected = _selectedMealType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMealType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? const Color(0xFF10B981) : Colors.transparent),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(color: color, fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}