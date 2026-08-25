import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/diary_entry_model.dart';
import '../pages/create_custom_food_page.dart';

class MealSectionCard extends StatelessWidget {
  final String title;
  final String icon;
  final String mealType;
  final List<DiaryEntryModel> items;
  final VoidCallback onAddPressed;
  final VoidCallback onCopyYesterdayPressed;
  final Function(DiaryEntryModel) onEditPressed;
  final Function(DiaryEntryModel) onDeletePressed;

  const MealSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.mealType,
    required this.items,
    required this.onAddPressed,
    required this.onCopyYesterdayPressed,
    required this.onEditPressed,
    required this.onDeletePressed,
  });

  String _formatMacro(double val) =>
      val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final int totalCalories =
        items.fold(0, (sum, item) => sum + item.calculatedCalories);

    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color itemBg =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color textColor =
        isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER BỮA ĂN
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: itemBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Text(
                      icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${items.length} món đã ghi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: subTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '$totalCalories',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: totalCalories > 0
                            ? const Color(0xFF10B981)
                            : subTextColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'kcal',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: subTextColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onAddPressed,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. TRẠNG THÁI TRỐNG HOẶC DANH SÁCH MÓN ĂN
            if (items.isEmpty)
              InkWell(
                onTap: onCopyYesterdayPressed,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: itemBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Chưa có món ăn',
                        style: GoogleFonts.plusJakartaSans(
                          color: subTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Lấy hôm qua',
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
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final food = item.food;
                  final foodName = (food?.name != null && food!.name.isNotEmpty)
                      ? food.name
                      : 'Món ăn dinh dưỡng';
                  final double qty = item.quantity;
                  final int cal = item.calculatedCalories;
                  final double carbs = item.calculatedCarbs;
                  final double protein = item.calculatedProtein;
                  final double fat = item.calculatedFat;

                  // Tự động tính toán lại chất xơ theo số gram tiêu thụ nếu calculatedFiber = 0/null
                  final double calculatedFiberVal = item.calculatedFiber ?? 0.0;
                  final double fiber = calculatedFiberVal > 0
                      ? calculatedFiberVal
                      : ((food?.fiberG ?? 0.0) * (qty / 100.0));

                  return Container(
                    decoration: BoxDecoration(
                      color: itemBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: borderColor.withValues(alpha: 0.7),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateCustomFoodPage(
                              isReadOnly: true,
                              initialEntry: item,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tên món + Calo + Nút sửa/xóa
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    foodName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: textColor,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$cal kcal',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => onEditPressed(item),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0EA5E9)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      size: 15,
                                      color: Color(0xFF0EA5E9),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => onDeletePressed(item),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 15,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Khối lượng + 4 Badges Macro (Carbs, Protein, Fat, Chất Xơ)
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: borderColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${qty.toStringAsFixed(0)}g',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: subTextColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _buildMacroBadge(
                                  'C',
                                  _formatMacro(carbs),
                                  const Color(0xFFF59E0B),
                                ),
                                _buildMacroBadge(
                                  'P',
                                  _formatMacro(protein),
                                  const Color(0xFF0EA5E9),
                                ),
                                _buildMacroBadge(
                                  'F',
                                  _formatMacro(fat),
                                  const Color(0xFFEC4899),
                                ),
                                if (fiber > 0)
                                  _buildMacroBadge(
                                    'X',
                                    _formatMacro(fiber),
                                    const Color(0xFFA855F7),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: ${value}g',
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}