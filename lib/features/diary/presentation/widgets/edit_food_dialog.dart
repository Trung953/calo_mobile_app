import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/diary_entry_model.dart';
import '../../data/models/food_model.dart';

class EditFoodDialog extends StatefulWidget {
  final DiaryEntryModel entry;
  final Future<void> Function(String mealType, double quantity) onUpdate;

  const EditFoodDialog({
    super.key,
    required this.entry,
    required this.onUpdate,
  });

  @override
  State<EditFoodDialog> createState() => _EditFoodDialogState();
}

class _EditFoodDialogState extends State<EditFoodDialog> {
  late TextEditingController _weightCtrl;
  late String _selectedMealType;
  bool _isSaving = false;

  late double _baseCalPer100;
  late double _baseCarbsPer100;
  late double _baseProteinPer100;
  late double _baseFatPer100;
  late double _baseFiberPer100;

  @override
  void initState() {
    super.initState();
    _selectedMealType = widget.entry.mealType;
    final double currentQty = widget.entry.quantity > 0 ? widget.entry.quantity : 100.0;
    _weightCtrl = TextEditingController(
      text: currentQty % 1 == 0 ? currentQty.toInt().toString() : currentQty.toStringAsFixed(1),
    );

    final food = widget.entry.food;

    // Chuẩn hóa tỷ lệ dinh dưỡng về mốc 100g chuẩn
    if (food != null && food.calories > 0) {
      final double serving = (food.servingSizeWeight != null && food.servingSizeWeight! > 0)
          ? food.servingSizeWeight!
          : 100.0;
      final double ratio = 100.0 / serving;

      _baseCalPer100 = food.calories * ratio;
      _baseCarbsPer100 = food.carbsG * ratio;
      _baseProteinPer100 = food.proteinG * ratio;
      _baseFatPer100 = food.fatG * ratio;
      _baseFiberPer100 = food.fiberG * ratio;
    } else {
      final double ratio = 100.0 / currentQty;
      _baseCalPer100 = widget.entry.calculatedCalories * ratio;
      _baseCarbsPer100 = widget.entry.calculatedCarbs * ratio;
      _baseProteinPer100 = widget.entry.calculatedProtein * ratio;
      _baseFatPer100 = widget.entry.calculatedFat * ratio;
      _baseFiberPer100 = (widget.entry.calculatedFiber ?? 0.0) * ratio;
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  String _getMealName(String type) {
    switch (type) {
      case 'BREAKFAST':
        return 'Bữa sáng';
      case 'LUNCH':
        return 'Bữa trưa';
      case 'DINNER':
        return 'Bữa tối';
      case 'SNACK':
        return 'Bữa phụ';
      default:
        return 'Bữa ăn';
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

    // Tính toán theo thời gian thực khi thay đổi khối lượng
    final double inputGrams = double.tryParse(_weightCtrl.text) ?? 0.0;
    final double currentRatio = inputGrams / 100.0;

    final int calcCal = (_baseCalPer100 * currentRatio).round();
    final double calcCarbs = _baseCarbsPer100 * currentRatio;
    final double calcProtein = _baseProteinPer100 * currentRatio;
    final double calcFat = _baseFatPer100 * currentRatio;
    final double calcFiber = _baseFiberPer100 * currentRatio;

    final String foodName = widget.entry.food?.name ?? 'Món ăn';

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
            // 1. TIÊU ĐỀ & NÚT ĐÓNG
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chỉnh sửa món ăn',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF10B981),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        foodName,
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

            // 2. THANH CHỌN BỮA ĂN NHANH
            Text(
              'Bữa ăn',
              style: GoogleFonts.plusJakartaSans(
                color: subTextColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
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

            // 3. Ô NHẬP KHỐI LƯỢNG (GRAM)
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
                      style: GoogleFonts.plusJakartaSans(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
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
                      widget.entry.food?.servingSizeUnit ?? 'g',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. KẾT QUẢ DINH DƯỠNG THỜI GIAN THỰC (CALO + 4 MACRO)
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
                        style: GoogleFonts.plusJakartaSans(
                          color: subTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
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

            // 5. NÚT XÁC NHẬN CẬP NHẬT
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
                        try {
                          await widget.onUpdate(_selectedMealType, inputGrams);
                          if (!mounted) return;
                          Navigator.pop(context, true);
                        } catch (_) {
                          if (mounted) setState(() => _isSaving = false);
                        }
                      },
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        'CẬP NHẬT VÀO ${_getMealName(_selectedMealType).toUpperCase()}',
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
            color: isSelected
                ? const Color(0xFF10B981)
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
            ),
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
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}