import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_toast.dart';

class AIDietPlanPage extends StatefulWidget {
  final ApiClient? apiClient;

  const AIDietPlanPage({super.key, this.apiClient});

  @override
  State<AIDietPlanPage> createState() => _AIDietPlanPageState();
}

class _AIDietPlanPageState extends State<AIDietPlanPage> {
  late final ApiClient _apiClient;
  final _formKey = GlobalKey<FormState>();

  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();

  String _gender = 'Nam';
  String _activityLevel = 'light';
  bool _isLoading = true;
  String _statusMessage = 'Đang đồng bộ hồ sơ thể chất...';
  Map<String, dynamic>? _planResult;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _loadProfileAndAutoGenerate();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  void _showFriendlyError(String rawError) {
    if (!mounted) return;
    final errText = rawError.toLowerCase();
    String message;

    if (errText.contains('429') ||
        errText.contains('quota') ||
        errText.contains('resource_exhausted')) {
      message = 'Hệ thống AI đang quá tải hạn mức. Vui lòng thử lại sau ít phút.';
    } else if (errText.contains('timeout') ||
        errText.contains('connection') ||
        errText.contains('network') ||
        errText.contains('socket')) {
      message = 'Lỗi kết nối mạng. Vui lòng kiểm tra lại Internet.';
    } else if (errText.contains('401') || errText.contains('unauthorized')) {
      message = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    } else {
      message = 'Không thể phân tích lộ trình lúc này. Vui lòng thử lại.';
    }

    AppToast.showError(context, message, title: 'Thông báo AI');
  }

  Future<void> _loadProfileAndAutoGenerate() async {
    try {
      final base = ApiEndpoints.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
      final url = '$base/api/v1/profile';

      final res = await _apiClient.get(url);

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        final profile = (data['profile'] is Map) ? data['profile'] : data;

        final rawGender = (profile['gender'] ?? '').toString().toUpperCase();
        _gender = rawGender == 'FEMALE' ? 'Nữ' : 'Nam';

        if (profile['birthDate'] != null) {
          final bDate = DateTime.tryParse(profile['birthDate'].toString());
          if (bDate != null) {
            final now = DateTime.now();
            int calculatedAge = now.year - bDate.year;
            if (now.month < bDate.month ||
                (now.month == bDate.month && now.day < bDate.day)) {
              calculatedAge--;
            }
            _ageController.text = calculatedAge.toString();
          }
        }

        final height = profile['heightCm'] ?? profile['height'];
        if (height != null) {
          _heightController.text = height.toString();
        }

        final weight = profile['currentWeightKg'] ??
            profile['currentWeight'] ??
            profile['weight'];
        if (weight != null) {
          final wNum = double.tryParse(weight.toString()) ?? 0;
          _weightController.text =
              wNum.toStringAsFixed(1).replaceAll('.0', '');
        }

        final targetWeight =
            profile['targetWeightKg'] ?? profile['targetWeight'];
        if (targetWeight != null) {
          final twNum = double.tryParse(targetWeight.toString()) ?? 0;
          _targetWeightController.text =
              twNum.toStringAsFixed(1).replaceAll('.0', '');
        } else if (_weightController.text.isNotEmpty) {
          final currentW =
              double.tryParse(_weightController.text) ?? 50.0;
          _targetWeightController.text =
              (currentW > 50 ? currentW - 4 : currentW - 2)
                  .toStringAsFixed(1)
                  .replaceAll('.0', '');
        }

        final activity =
            profile['activityLevel']?.toString().toLowerCase();
        if (activity != null) {
          if (activity.contains('sedentary')) {
            _activityLevel = 'sedentary';
          } else if (activity.contains('light')) {
            _activityLevel = 'light';
          } else if (activity.contains('moderate')) {
            _activityLevel = 'moderate';
          } else if (activity.contains('very')) {
            _activityLevel = 'active';
          } else {
            _activityLevel = 'light';
          }
        }

        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Lỗi tải profile AI: $e');
    }

    if (mounted) {
      setState(() {
        _statusMessage = 'AI đang phân tích thể trạng & lập thực đơn...';
      });
      await _generatePlan();
    }
  }

  Future<void> _generatePlan({bool useBackupKey = false}) async {
    setState(() => _isLoading = true);
    try {
      final base = ApiEndpoints.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
      final url = '$base/api/v1/ai/generate-diet-plan';

      final res = await _apiClient.post(url, {
        'gender': _gender,
        'age': int.tryParse(_ageController.text) ?? 24,
        'heightCm': double.tryParse(_heightController.text) ?? 170,
        'weightKg': double.tryParse(_weightController.text) ?? 65,
        'targetWeightKg':
            double.tryParse(_targetWeightController.text) ?? 58,
        'activityLevel': _activityLevel,
        'useBackupKey': useBackupKey,
      });

      if (res['success'] == true && res['data'] != null) {
        if (!mounted) return;
        setState(() => _planResult = res['data']);
        AppToast.showSuccess(context, 'Đã hoàn tất lộ trình & thực đơn đề xuất');
      }
    } catch (e) {
      final errText = e.toString().toLowerCase();
      if (!useBackupKey &&
          (errText.contains('429') ||
              errText.contains('quota') ||
              errText.contains('resource_exhausted'))) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Đang kích hoạt máy chủ AI dự phòng (Key 2)...';
          });
        }
        await _generatePlan(useBackupKey: true);
        return;
      }

      _showFriendlyError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const primaryColor = Color(0xFF10B981);
    final bgColor =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputFill =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    // Tính toán tiêu đề lộ trình tự động theo mục tiêu cân nặng
    String roadmapTitle = '🏁 Lộ trình vóc dáng';
    if (_planResult != null) {
      if (_planResult!['goalTitle'] != null &&
          _planResult!['goalTitle'].toString().isNotEmpty) {
        roadmapTitle = '🏁 ${_planResult!['goalTitle']}';
      } else {
        final currentW = double.tryParse(_weightController.text) ?? 65.0;
        final targetW = double.tryParse(_targetWeightController.text) ?? 58.0;
        final weeks = _planResult!['estimatedWeeks'] ?? 12;

        if (targetW > currentW) {
          roadmapTitle = '🏁 Lộ trình tăng cân ($weeks tuần)';
        } else if (targetW < currentW) {
          roadmapTitle = '🏁 Lộ trình giảm cân ($weeks tuần)';
        } else {
          roadmapTitle = '🏁 Lộ trình duy trì vóc dáng ($weeks tuần)';
        }
      }
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'AI Lộ Trình & Thực Đơn',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 18, color: textColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Thông số thể trạng',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textColor),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '✓ Hồ sơ thể chất',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: primaryColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _gender,
                            dropdownColor: cardBg,
                            decoration: _inputDecor('Giới tính', inputFill,
                                borderColor, subTextColor),
                            style: GoogleFonts.plusJakartaSans(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                            items: [
                              DropdownMenuItem(
                                  value: 'Nam',
                                  child: Text('Nam',
                                      style: TextStyle(color: textColor))),
                              DropdownMenuItem(
                                  value: 'Nữ',
                                  child: Text('Nữ',
                                      style: TextStyle(color: textColor))),
                            ],
                            onChanged: (val) =>
                                setState(() => _gender = val!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.plusJakartaSans(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                            decoration: _inputDecor('Tuổi', inputFill,
                                borderColor, subTextColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.plusJakartaSans(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                            decoration: _inputDecor('Cao (cm)', inputFill,
                                borderColor, subTextColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            style: GoogleFonts.plusJakartaSans(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                            decoration: _inputDecor('Hiện tại (kg)',
                                inputFill, borderColor, subTextColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _targetWeightController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            style: GoogleFonts.plusJakartaSans(
                                color: primaryColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14),
                            decoration: _inputDecor('Mục tiêu (kg)',
                                inputFill, borderColor, subTextColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _generatePlan(),
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 18),
                      label: Text(
                        _isLoading
                            ? 'Đang phân tích...'
                            : 'Tính lại Lộ trình & Thực đơn',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 36),
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 14),
                    Text(
                      _statusMessage,
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          color: subTextColor,
                          fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            if (!_isLoading && _planResult != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF134E4A).withValues(alpha: 0.35)
                      : const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricItem(
                            'BMI',
                            '${_planResult!['bmi']}',
                            _planResult!['bmiClassification'] ??
                                'Bình thường',
                            textColor,
                            primaryColor,
                            subTextColor),
                        _metricItem(
                            'BMR',
                            '${_planResult!['bmr']} kcal',
                            'Chuyển hóa cơ bản',
                            textColor,
                            primaryColor,
                            subTextColor),
                        _metricItem(
                            'TDEE',
                            '${_planResult!['tdee']} kcal',
                            'Tiêu hao mỗi ngày',
                            textColor,
                            primaryColor,
                            subTextColor),
                      ],
                    ),
                    Divider(color: borderColor, height: 24),
                    Text(
                      '🔥 Calo mục tiêu: ${_planResult!['targetCalories']} kcal/ngày',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF0F766E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionTitle(roadmapTitle, textColor),
              ...(_planResult!['roadmap'] as List? ?? []).map((phase) =>
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.2 : 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(phase['phase'] ?? '',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                color: textColor)),
                        const SizedBox(height: 4),
                        Text(
                          '🎯 Mục tiêu: ${phase['target']}',
                          style: GoogleFonts.plusJakartaSans(
                              color: primaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '⚡ Trọng tâm: ${phase['focus']}',
                          style: GoogleFonts.plusJakartaSans(
                              color: subTextColor, fontSize: 13),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              _buildSectionTitle('🥗 Thực đơn gợi ý 7 ngày', textColor),
              ...(_planResult!['weeklyMealPlan'] as List? ?? []).map((day) =>
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.2 : 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              day['day'] ?? '',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: textColor),
                            ),
                            Text(
                              '${day['totalCalories']} kcal',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFEF4444),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                        Divider(color: borderColor, height: 16),
                        _mealRow('Sáng', day['meals']?['breakfast'],
                            textColor, subTextColor),
                        _mealRow('Trưa', day['meals']?['lunch'], textColor,
                            subTextColor),
                        _mealRow('Phụ', day['meals']?['snack'], textColor,
                            subTextColor),
                        _mealRow('Tối', day['meals']?['dinner'], textColor,
                            subTextColor),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricItem(String label, String value, String sub, Color textColor,
      Color primaryColor, Color subTextColor) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
                color: subTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
                color: textColor, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
                color: primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _mealRow(String title, String? content, Color textColor,
      Color subTextColor) {
    if (content == null || content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 45,
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: subTextColor,
                  fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              content,
              style: GoogleFonts.plusJakartaSans(
                  color: textColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
            fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }

  InputDecoration _inputDecor(
      String label, Color fillColor, Color borderColor, Color hintColor) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(
          color: hintColor, fontSize: 13, fontWeight: FontWeight.w500),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: fillColor,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor)),
      focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: Color(0xFF10B981), width: 1.5)),
    );
  }
}