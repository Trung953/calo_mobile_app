import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';

class WaterTrackerCard extends StatefulWidget {
  final ApiClient apiClient;
  final DateTime selectedDate;
  final int? targetWaterMl;

  const WaterTrackerCard({
    super.key,
    required this.apiClient,
    required this.selectedDate,
    this.targetWaterMl,
  });

  @override
  State<WaterTrackerCard> createState() => _WaterTrackerCardState();
}

class _WaterTrackerCardState extends State<WaterTrackerCard> {
  int _totalAmountMl = 0;
  bool _isLoading = false;

  int get displayTarget => widget.targetWaterMl ?? 2000;

  @override
  void initState() {
    super.initState();
    _fetchWater();
  }

  @override
  void didUpdateWidget(covariant WaterTrackerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.targetWaterMl != widget.targetWaterMl) {
      _fetchWater();
    }
  }

  Future<void> _fetchWater() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    try {
      final res = await widget.apiClient.get('${ApiEndpoints.water}?date=$dateStr');
      final data = res['data'] ?? res;
      if (data != null && mounted) {
        setState(() {
          _totalAmountMl = (data['totalAmountMl'] as num?)?.toInt() ??
              (data['amountMl'] as num?)?.toInt() ??
              (data['amount'] as num?)?.toInt() ??
              0;
        });
      }
    } catch (_) {}
  }

  Future<void> _addWater(int amountMl) async {
    setState(() => _isLoading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    try {
      final res = await widget.apiClient.post(ApiEndpoints.water, {
        'amountMl': amountMl,
        'amount': amountMl,
        'date': dateStr,
      });
      final data = res['data'] ?? res;
      if (data != null && mounted) {
        setState(() {
          _totalAmountMl = (data['totalAmountMl'] as num?)?.toInt() ?? (_totalAmountMl + amountMl);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetWater() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
    try {
      setState(() => _totalAmountMl = 0);
      await widget.apiClient.delete('${ApiEndpoints.water}/reset?date=$dateStr');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int target = displayTarget;
    final double progress = target > 0 ? (_totalAmountMl / target).clamp(0.0, 1.0) : 0.0;

    final Color cardBg = isDark ? const Color(0xFF161F30) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color borderColor = isDark ? const Color(0xFF26354A) : const Color(0xFFE2E8F0);
    final Color barTrackColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0);

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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: Color(0xFF38BDF8),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nước Uống',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$_totalAmountMl',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                  Text(
                    ' / $target ml',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
              if (_totalAmountMl > 0) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _resetWater,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: borderColor.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: subTextColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: barTrackColor,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildQuickAddButton(100, isDark),
              const SizedBox(width: 8),
              _buildQuickAddButton(250, isDark),
              const SizedBox(width: 8),
              _buildQuickAddButton(500, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButton(int amount, bool isDark) {
    return Expanded(
      child: InkWell(
        onTap: _isLoading ? null : () => _addWater(amount),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF38BDF8).withValues(alpha: isDark ? 0.08 : 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
            ),
          ),
          child: Center(
            child: Text(
              '+$amount ml',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF38BDF8),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}