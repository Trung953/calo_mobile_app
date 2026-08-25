import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/utils/app_toast.dart';

class PhysicalProfilePage extends StatefulWidget {
  final ApiClient apiClient;

  const PhysicalProfilePage({super.key, required this.apiClient});

  @override
  State<PhysicalProfilePage> createState() => _PhysicalProfilePageState();
}

class _PhysicalProfilePageState extends State<PhysicalProfilePage> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Dữ liệu chỉ số
  String _gender = 'MALE';
  int _age = 24;
  double _heightCm = 170.0;
  double _currentWeightKg = 65.0;
  double _targetWeightKg = 50.0;
  int _targetWaterMl = 2000;
  String _activityLevel = 'LIGHTLY_ACTIVE';
  String _goal = 'LOSE_WEIGHT';

  // Số đo 3 vòng
  double? _bustCm;
  double? _waistCm;
  double? _hipsCm;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await widget.apiClient.get(ApiEndpoints.profile);
      final raw = res['data'] ?? res;
      final profile = raw is Map ? (raw['profile'] ?? raw) : {};

      if (mounted && profile is Map) {
        setState(() {
          _gender = profile['gender'] ?? 'MALE';
          _heightCm = (profile['heightCm'] as num?)?.toDouble() ?? 170.0;
          _currentWeightKg = (profile['currentWeightKg'] as num?)?.toDouble() ?? 65.0;
          _targetWeightKg = (profile['targetWeightKg'] as num?)?.toDouble() ?? 50.0;
          
          final savedWater = (profile['targetWaterMl'] as num?)?.toInt() ??
              (profile['targetWater'] as num?)?.toInt() ??
              (profile['waterTarget'] as num?)?.toInt();

          if (savedWater != null && savedWater > 0) {
            _targetWaterMl = savedWater;
          } else {
            _targetWaterMl = ((_currentWeightKg * 35).round() ~/ 100 * 100).clamp(1500, 4000);
          }

          _activityLevel = profile['activityLevel'] ?? 'LIGHTLY_ACTIVE';
          _goal = profile['goal'] ?? (_targetWeightKg < _currentWeightKg ? 'LOSE_WEIGHT' : 'MAINTAIN');

          _bustCm = (profile['bustCm'] as num?)?.toDouble();
          _waistCm = (profile['waistCm'] as num?)?.toDouble();
          _hipsCm = (profile['hipsCm'] as num?)?.toDouble();

          if (profile['birthDate'] != null) {
            final bDate = DateTime.tryParse(profile['birthDate'].toString());
            if (bDate != null) {
              _age = DateTime.now().year - bDate.year;
              if (_age <= 0) _age = 24;
            }
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // CÔNG THỨC KHOA HỌC MIFFLIN-ST JEOR
  int get calculatedTdee {
    double bmr = 10 * _currentWeightKg + 6.25 * _heightCm - 5 * _age;
    bmr += (_gender == 'MALE') ? 5 : -161;

    double multiplier = 1.2;
    switch (_activityLevel) {
      case 'SEDENTARY': multiplier = 1.2; break;
      case 'LIGHTLY_ACTIVE': multiplier = 1.375; break;
      case 'MODERATELY_ACTIVE': multiplier = 1.55; break;
      case 'VERY_ACTIVE': multiplier = 1.725; break;
      case 'EXTRA_ACTIVE': multiplier = 1.9; break;
    }
    return (bmr * multiplier).round();
  }

  int get calculatedTargetCalories {
    int target = calculatedTdee;
    switch (_goal) {
      case 'LOSE_WEIGHT_FAST': target -= 700; break;
      case 'LOSE_WEIGHT': target -= 500; break;
      case 'MAINTAIN': break;
      case 'GAIN_WEIGHT': target += 300; break;
      case 'GAIN_WEIGHT_FAST': target += 500; break;
      default:
        if (_targetWeightKg < _currentWeightKg - 0.5) target -= 500;
        break;
    }
    return target < 1200 ? 1200 : target;
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final birthYear = DateTime.now().year - _age;
      final birthDate = '$birthYear-01-01';

      await widget.apiClient.put(ApiEndpoints.profile, {
        'gender': _gender,
        'birthDate': birthDate,
        'heightCm': _heightCm,
        'height': _heightCm,
        'currentWeightKg': _currentWeightKg,
        'weight': _currentWeightKg,
        'targetWeightKg': _targetWeightKg,
        'targetWeight': _targetWeightKg,
        'targetWaterMl': _targetWaterMl,
        'targetWater': _targetWaterMl,
        'waterTarget': _targetWaterMl,
        'bustCm': _bustCm,
        'waistCm': _waistCm,
        'hipsCm': _hipsCm,
        'activityLevel': _activityLevel,
        'goal': _goal,
        'targetCalories': calculatedTargetCalories,
        'tdee': calculatedTdee,
      });

      try {
        await widget.apiClient.put('${ApiEndpoints.water}/target', {
          'targetAmountMl': _targetWaterMl,
          'targetWater': _targetWaterMl,
        });
      } catch (_) {}

      if (!mounted) return;
      AppToast.showSuccess(context, 'Đã cập nhật hồ sơ thể chất & chỉ số thành công!');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e, title: 'Không thể cập nhật hồ sơ');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Dialog nhập số
  void _showEditNumberDialog({
    required String title,
    required double? initialValue,
    required String unit,
    required bool isDark,
    required Function(double) onSaved,
  }) {
    final ctrl = TextEditingController(
      text: initialValue != null
          ? (initialValue % 1 == 0 ? initialValue.toInt().toString() : initialValue.toStringAsFixed(1))
          : '',
    );
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: GoogleFonts.plusJakartaSans(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            suffixText: unit,
            suffixStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF10B981), fontSize: 16),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Hủy', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                Navigator.of(dialogCtx).pop();
                setState(() => onSaved(val));
              } else {
                AppToast.showError(context, 'Vui lòng nhập giá trị hợp lệ');
              }
            },
            child: Text('Xác nhận', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Dialog chọn Mục tiêu & Tốc độ
  void _showGoalBottomSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mục tiêu dinh dưỡng',
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildGoalItem('Giảm cân nhanh (-700 kcal/ngày)', 'LOSE_WEIGHT_FAST', isDark, ctx),
            _buildGoalItem('Giảm cân chuẩn (-500 kcal/ngày)', 'LOSE_WEIGHT', isDark, ctx),
            _buildGoalItem('Giữ nguyên cân nặng (Maintain)', 'MAINTAIN', isDark, ctx),
            _buildGoalItem('Tăng cân & Tăng cơ (+300 kcal/ngày)', 'GAIN_WEIGHT', isDark, ctx),
            _buildGoalItem('Tăng cân nhanh (+500 kcal/ngày)', 'GAIN_WEIGHT_FAST', isDark, ctx),
          ],
        ),
      ),
    );
  }

  // Dialog chọn Mức độ vận động
  void _showActivityBottomSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mức độ vận động thể chất',
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildActivityItem('Ít vận động (Văn phòng, ngồi nhiều)', 'SEDENTARY', 1.2, isDark, ctx),
            _buildActivityItem('Vận động nhẹ (Tập nhẹ 1-3 ngày/tuần)', 'LIGHTLY_ACTIVE', 1.375, isDark, ctx),
            _buildActivityItem('Vận động vừa (Tập 3-5 ngày/tuần)', 'MODERATELY_ACTIVE', 1.55, isDark, ctx),
            _buildActivityItem('Vận động nhiều (Tập 6-7 ngày/tuần)', 'VERY_ACTIVE', 1.725, isDark, ctx),
            _buildActivityItem('Vận động cực nhiều (VĐV, lao động nặng)', 'EXTRA_ACTIVE', 1.9, isDark, ctx),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
        final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

        if (_isLoading) {
          return Scaffold(
            backgroundColor: bgColor,
            body: const Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
          );
        }

        final diff = _targetWeightKg - _currentWeightKg;
        String goalTitle = 'Duy trì cân nặng';
        if (diff < -0.1) {
          goalTitle = 'Giảm xuống ${_targetWeightKg.toStringAsFixed(1)} kg (${(-diff).toStringAsFixed(1)} kg)';
        } else if (diff > 0.1) {
          goalTitle = 'Tăng lên ${_targetWeightKg.toStringAsFixed(1)} kg (+${diff.toStringAsFixed(1)} kg)';
        }

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Hồ sơ thể chất',
              style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            centerTitle: true,
            actions: [
              TextButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2))
                    : Text('Lưu', style: GoogleFonts.plusJakartaSans(color: const Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Card 1: Cân nặng, Chiều cao, Tuổi
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildListRow(
                        label: 'Cân nặng hiện tại',
                        value: '${_currentWeightKg.toStringAsFixed(1)} kg',
                        textColor: textColor,
                        subColor: subColor,
                        onTap: () => _showEditNumberDialog(
                          title: 'Cập nhật Cân nặng',
                          initialValue: _currentWeightKg,
                          unit: 'kg',
                          isDark: isDark,
                          onSaved: (v) => _currentWeightKg = v,
                        ),
                      ),
                      Divider(color: borderColor, height: 1),
                      _buildListRow(
                        label: 'Chiều cao',
                        value: '${_heightCm.toStringAsFixed(0)} cm',
                        textColor: textColor,
                        subColor: subColor,
                        onTap: () => _showEditNumberDialog(
                          title: 'Cập nhật Chiều cao',
                          initialValue: _heightCm,
                          unit: 'cm',
                          isDark: isDark,
                          onSaved: (v) => _heightCm = v,
                        ),
                      ),
                      Divider(color: borderColor, height: 1),
                      _buildListRow(
                        label: 'Tuổi',
                        value: '$_age tuổi',
                        textColor: textColor,
                        subColor: subColor,
                        onTap: () => _showEditNumberDialog(
                          title: 'Cập nhật Tuổi',
                          initialValue: _age.toDouble(),
                          unit: 'tuổi',
                          isDark: isDark,
                          onSaved: (v) => _age = v.toInt(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Card 2: Số đo 3 vòng
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildListRow(
                        label: 'Vòng 1 (Ngực)',
                        value: _bustCm != null ? '${_bustCm!.toStringAsFixed(1)} cm' : '– cm',
                        textColor: textColor,
                        subColor: subColor,
                        onTap: () => _showEditNumberDialog(
                          title: 'Số đo Vòng 1 (Ngực)',
                          initialValue: _bustCm,
                          unit: 'cm',
                          isDark: isDark,
                          onSaved: (v) => _bustCm = v,
                        ),
                      ),
                      Divider(color: borderColor, height: 1),
                      _buildListRow(
                        label: 'Vòng 2 (Eo)',
                        value: _waistCm != null ? '${_waistCm!.toStringAsFixed(1)} cm' : '– cm',
                        textColor: textColor,
                        subColor: subColor,
                        onTap: () => _showEditNumberDialog(
                          title: 'Số đo Vòng 2 (Eo)',
                          initialValue: _waistCm,
                          unit: 'cm',
                          isDark: isDark,
                          onSaved: (v) => _waistCm = v,
                        ),
                      ),
                      Divider(color: borderColor, height: 1),
                      _buildListRow(
                        label: 'Vòng 3 (Mông)',
                        value: _hipsCm != null ? '${_hipsCm!.toStringAsFixed(1)} cm' : '– cm',
                        textColor: textColor,
                        subColor: subColor,
                        onTap: () => _showEditNumberDialog(
                          title: 'Số đo Vòng 3 (Mông)',
                          initialValue: _hipsCm,
                          unit: 'cm',
                          isDark: isDark,
                          onSaved: (v) => _hipsCm = v,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Card 3: Mức độ vận động
                _buildInteractiveCard(
                  title: 'Mức độ vận động',
                  subtitle: _getActivityLabel(_activityLevel),
                  icon: Icons.directions_run_rounded,
                  cardBg: cardBg,
                  textColor: textColor,
                  subColor: subColor,
                  borderColor: borderColor,
                  onTap: () => _showActivityBottomSheet(isDark),
                ),
                const SizedBox(height: 14),

                // Card 4: Mục tiêu cân nặng & Nước uống
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildListRow(
                        label: 'Mục tiêu cân nặng',
                        value: '${_targetWeightKg.toStringAsFixed(1)} kg',
                        textColor: textColor,
                        subColor: subColor,
                        onTap: () {
                          _showEditNumberDialog(
                            title: 'Cân nặng mong muốn',
                            initialValue: _targetWeightKg,
                            unit: 'kg',
                            isDark: isDark,
                            onSaved: (v) {
                              _targetWeightKg = v;
                              if (_targetWeightKg < _currentWeightKg - 0.5) {
                                _goal = 'LOSE_WEIGHT';
                              } else if (_targetWeightKg > _currentWeightKg + 0.5) {
                                _goal = 'GAIN_WEIGHT';
                              } else {
                                _goal = 'MAINTAIN';
                              }
                              _showGoalBottomSheet(isDark);
                            },
                          );
                        },
                      ),
                      Divider(color: borderColor, height: 1),
                      _buildListRowStatic(
                        label: 'Mục tiêu uống nước',
                        value: '${(_currentWeightKg * 35).round()} ml/ngày',
                        textColor: textColor,
                        subColor: subColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Card 5: LƯỢNG CALO CẦN NẠP
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Lượng Calo cần nạp',
                            style: GoogleFonts.plusJakartaSans(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '$calculatedTargetCalories',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF10B981),
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lượng Calo nạp vào hàng ngày để đạt được mục tiêu cân nặng mong muốn của bạn.',
                        style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 13, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Card 6: CHỈ SỐ TDEE
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Chỉ số TDEE (kcal)',
                            style: GoogleFonts.plusJakartaSans(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '$calculatedTdee',
                            style: GoogleFonts.plusJakartaSans(color: textColor, fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lượng Calo cơ thể bạn tự tiêu thụ trong 1 ngày dựa trên chiều cao, cân nặng và mức vận động.',
                        style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 13, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListRow({
    required String label,
    required String value,
    required Color textColor,
    required Color subColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(color: textColor, fontSize: 15, fontWeight: FontWeight.w500)),
            Row(
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFF10B981), fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_ios_rounded, color: subColor, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color cardBg,
    required Color textColor,
    required Color subColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 13.5)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: subColor, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalItem(String label, String value, bool isDark, BuildContext ctx) {
    final isSelected = _goal == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: isSelected ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF0F172A)),
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)) : null,
      onTap: () {
        setState(() => _goal = value);
        Navigator.pop(ctx);
      },
    );
  }

  Widget _buildActivityItem(String label, String value, double factor, bool isDark, BuildContext ctx) {
    final isSelected = _activityLevel == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: isSelected ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF0F172A)),
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      trailing: Text('x$factor', style: GoogleFonts.plusJakartaSans(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.bold)),
      onTap: () {
        setState(() => _activityLevel = value);
        Navigator.pop(ctx);
      },
    );
  }

  String _getActivityLabel(String level) {
    switch (level) {
      case 'SEDENTARY': return 'Ít vận động: 1.2';
      case 'LIGHTLY_ACTIVE': return 'Vận động nhẹ: 1.375';
      case 'MODERATELY_ACTIVE': return 'Vận động vừa: 1.55';
      case 'VERY_ACTIVE': return 'Vận động nhiều: 1.725';
      case 'EXTRA_ACTIVE': return 'Vận động cực nhiều: 1.9';
      default: return 'Vận động nhẹ: 1.375';
    }
  }

  Widget _buildListRowStatic({
    required String label,
    required String value,
    required Color textColor,
    required Color subColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(color: textColor, fontSize: 15, fontWeight: FontWeight.w500)),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF38BDF8), fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}