import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../diary/data/models/diary_entry_model.dart';

class ScanFoodDetailDialog extends StatelessWidget {
  final DiaryEntryModel entry;

  const ScanFoodDetailDialog({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final food = entry.food;
    final double qty = (entry.quantity ?? 1).toDouble();
    
    // Tính tổng calo và macro theo số lượng phần ăn
    final int cal = entry.calculatedCalories ?? ((food?.calories ?? 0) * qty).round();
    final double carbs = (food?.carbsG ?? 0).toDouble() * qty;
    final double protein = (food?.proteinG ?? 0).toDouble() * qty;
    final double fat = (food?.fatG ?? 0).toDouble() * qty;

    return Dialog(
      backgroundColor: bgColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + Title + Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Chi Tiết Quét AI',
                        style: GoogleFonts.plusJakartaSans(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded, color: subTextColor, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nội dung cuộn linh hoạt khi description dài
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên món và tổng calo
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: subBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              food?.name ?? 'Món ăn',
                              style: GoogleFonts.plusJakartaSans(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '$cal kcal',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '•  Số lượng: ${entry.quantity ?? 1} phần',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: subTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 3 Chỉ số Macro
                      Row(
                        children: [
                          _buildMacroItem('Tinh bột', '${carbs.round()}g', const Color(0xFF0EA5E9), subBg, subTextColor),
                          const SizedBox(width: 8),
                          _buildMacroItem('Đạm', '${protein.round()}g', const Color(0xFF10B981), subBg, subTextColor),
                          const SizedBox(width: 8),
                          _buildMacroItem('Béo', '${fat.round()}g', const Color(0xFFF59E0B), subBg, subTextColor),
                        ],
                      ),

                      // Mô tả chi tiết phân tích
                      if (food?.description != null && food!.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Thành phần chi tiết đã phân tích:',
                          style: GoogleFonts.plusJakartaSans(
                            color: subTextColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: subBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            food.description!,
                            style: GoogleFonts.plusJakartaSans(
                              color: textColor,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Nút Đóng
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    foregroundColor: textColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Đóng',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, Color color, Color bg, Color subColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 11.5)),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../diary/data/models/diary_entry_model.dart';

class ScanFoodDetailDialog extends StatelessWidget {
  final DiaryEntryModel entry;

  const ScanFoodDetailDialog({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final food = entry.food;
    final double qty = (entry.quantity ?? 1).toDouble();
    
    // Tính tổng calo và macro theo số lượng phần ăn
    final int cal = entry.calculatedCalories ?? ((food?.calories ?? 0) * qty).round();
    final double carbs = (food?.carbsG ?? 0).toDouble() * qty;
    final double protein = (food?.proteinG ?? 0).toDouble() * qty;
    final double fat = (food?.fatG ?? 0).toDouble() * qty;

    return Dialog(
      backgroundColor: bgColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + Title + Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Chi Tiết Quét AI',
                        style: GoogleFonts.plusJakartaSans(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded, color: subTextColor, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nội dung cuộn linh hoạt khi description dài
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên món và tổng calo
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: subBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              food?.name ?? 'Món ăn',
                              style: GoogleFonts.plusJakartaSans(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '$cal kcal',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '•  Số lượng: ${entry.quantity ?? 1} phần',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: subTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 3 Chỉ số Macro
                      Row(
                        children: [
                          _buildMacroItem('Tinh bột', '${carbs.round()}g', const Color(0xFF0EA5E9), subBg, subTextColor),
                          const SizedBox(width: 8),
                          _buildMacroItem('Đạm', '${protein.round()}g', const Color(0xFF10B981), subBg, subTextColor),
                          const SizedBox(width: 8),
                          _buildMacroItem('Béo', '${fat.round()}g', const Color(0xFFF59E0B), subBg, subTextColor),
                        ],
                      ),

                      // Mô tả chi tiết phân tích
                      if (food?.description != null && food!.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Thành phần chi tiết đã phân tích:',
                          style: GoogleFonts.plusJakartaSans(
                            color: subTextColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: subBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            food.description!,
                            style: GoogleFonts.plusJakartaSans(
                              color: textColor,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Nút Đóng
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    foregroundColor: textColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Đóng',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, Color color, Color bg, Color subColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 11.5)),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}