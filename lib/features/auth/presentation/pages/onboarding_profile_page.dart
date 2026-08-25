import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../diary/presentation/pages/diary_page.dart';

class OnboardingProfilePage extends StatefulWidget {
  final ApiClient apiClient;
  final String? initialName;

  const OnboardingProfilePage({super.key, required this.apiClient, this.initialName});

  @override
  State<OnboardingProfilePage> createState() => _OnboardingProfilePageState();
}

class _OnboardingProfilePageState extends State<OnboardingProfilePage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  late TextEditingController _nameController;
  final TextEditingController _bustController = TextEditingController();
  final TextEditingController _waistController = TextEditingController();
  final TextEditingController _hipsController = TextEditingController();

  int _age = 24;
  String _gender = 'MALE';
  double _heightCm = 170.0;
  double _weightKg = 65.0;
  double _targetWeightKg = 60.0;

  late FixedExtentScrollController _agePickerCtrl;
  late FixedExtentScrollController _heightPickerCtrl;
  late FixedExtentScrollController _weightIntPickerCtrl;
  late FixedExtentScrollController _weightDecPickerCtrl;
  late FixedExtentScrollController _targetWeightIntPickerCtrl;
  late FixedExtentScrollController _targetWeightDecPickerCtrl;

  String _speedGoal = 'LOSE_WEIGHT';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');

    _agePickerCtrl = FixedExtentScrollController(initialItem: _age - 12);
    _heightPickerCtrl = FixedExtentScrollController(initialItem: (_heightCm - 130).round());
    _weightIntPickerCtrl = FixedExtentScrollController(initialItem: _weightKg.toInt() - 30);
    _weightDecPickerCtrl = FixedExtentScrollController(initialItem: ((_weightKg % 1) * 10).round());
    _targetWeightIntPickerCtrl = FixedExtentScrollController(initialItem: _targetWeightKg.toInt() - 30);
    _targetWeightDecPickerCtrl = FixedExtentScrollController(initialItem: ((_targetWeightKg % 1) * 10).round());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bustController.dispose();
    _waistController.dispose();
    _hipsController.dispose();
    _agePickerCtrl.dispose();
    _heightPickerCtrl.dispose();
    _weightIntPickerCtrl.dispose();
    _weightDecPickerCtrl.dispose();
    _targetWeightIntPickerCtrl.dispose();
    _targetWeightDecPickerCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    FocusScope.of(context).unfocus();
    if (_currentStep < 7) {
      if (_currentStep == 4) {
        _targetWeightKg = _weightKg;
        if (_targetWeightIntPickerCtrl.hasClients) {
          _targetWeightIntPickerCtrl.jumpToItem(_targetWeightKg.toInt() - 30);
        }
        if (_targetWeightDecPickerCtrl.hasClients) {
          _targetWeightDecPickerCtrl.jumpToItem(((_targetWeightKg % 1) * 10).round());
        }
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _submitData();
    }
  }

  void _previousPage() {
    FocusScope.of(context).unfocus();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  Map<String, dynamic> _calculateNutritionPreview() {
    double bmr = 10 * _weightKg + 6.25 * _heightCm - 5 * _age;
    bmr += (_gender == 'MALE') ? 5 : -161;

    int tdee = (bmr * 1.375).round();

    int targetCalories = tdee;
    if (_speedGoal == 'LOSE_WEIGHT_FAST') {
      targetCalories -= 700;
    } else if (_speedGoal == 'LOSE_WEIGHT') {
      targetCalories -= 500;
    } else if (_speedGoal == 'LOSE_WEIGHT_SLOW') {
      targetCalories -= 300;
    } else if (_speedGoal == 'GAIN_WEIGHT_SLOW') {
      targetCalories += 200;
    } else if (_speedGoal == 'GAIN_WEIGHT') {
      targetCalories += 400;
    } else if (_speedGoal == 'GAIN_WEIGHT_FAST') {
      targetCalories += 600;
    }

    targetCalories = targetCalories < 1200 ? 1200 : targetCalories;

    final carbsG = ((targetCalories * 0.5) / 4).round();
    final proteinG = ((targetCalories * 0.25) / 4).round();
    final fatG = ((targetCalories * 0.25) / 9).round();

    return {
      'tdee': tdee,
      'calories': targetCalories,
      'carbs': carbsG,
      'protein': proteinG,
      'fat': fatG,
    };
  }

  Future<void> _submitData() async {
    setState(() => _isSaving = true);
    try {
      final birthYear = DateTime.now().year - _age;
      final birthDate = '$birthYear-01-01';

      String dbGoal = 'MAINTAIN';
      if (_speedGoal.contains('LOSE_WEIGHT_FAST')) {
        dbGoal = 'LOSE_WEIGHT_FAST';
      } else if (_speedGoal.contains('LOSE')) {
        dbGoal = 'LOSE_WEIGHT';
      } else if (_speedGoal.contains('GAIN_WEIGHT_FAST')) {
        dbGoal = 'GAIN_WEIGHT_FAST';
      } else if (_speedGoal.contains('GAIN')) {
        dbGoal = 'GAIN_WEIGHT';
      }

      await widget.apiClient.put(ApiEndpoints.profile, {
        'fullName': _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Người dùng',
        'gender': _gender,
        'birthDate': birthDate,
        'heightCm': _heightCm,
        'currentWeightKg': _weightKg,
        'targetWeightKg': _targetWeightKg,
        'bustCm': double.tryParse(_bustController.text.trim()),
        'waistCm': double.tryParse(_waistController.text.trim()),
        'hipsCm': double.tryParse(_hipsController.text.trim()),
        'goal': dbGoal,
        'activityLevel': 'LIGHTLY_ACTIVE',
        'isOnboarded': true,
      });

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DiaryPage()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu hồ sơ: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    IconButton(
                      onPressed: _previousPage,
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / 8,
                        minHeight: 5,
                        backgroundColor: const Color(0xFF1E293B),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${_currentStep + 1}/8',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentStep = idx),
                children: [
                  _buildNameStep(),
                  _buildAgeStep(),
                  _buildGenderStep(),
                  _buildHeightStep(),
                  _buildCurrentWeightStep(),
                  _buildTargetWeightStep(),
                  _buildSpeedGoalStep(),
                  _buildBodyMeasurementsStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameStep() {
    return _buildTemplate(
      icon: Icons.person_pin_circle_rounded,
      title: 'Tên của bạn là gì?',
      subtitle: 'HealthLog sẽ đồng hành cùng bạn thiết lập kế hoạch dinh dưỡng',
      content: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF162032),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: TextField(
          controller: _nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            hintText: 'Nhập tên của bạn...',
            hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 16),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.badge_outlined, color: Color(0xFF2DD4BF)),
          ),
        ),
      ),
    );
  }

  Widget _buildAgeStep() {
    return _buildTemplate(
      icon: Icons.cake_rounded,
      title: 'Bạn bao nhiêu tuổi?',
      subtitle: 'Độ tuổi giúp xác định tỉ lệ trao đổi chất cơ bản (BMR)',
      content: Column(
        children: [
          _buildBigDisplayHeader('$_age', 'tuổi'),
          const SizedBox(height: 24),
          _buildProIosPickerBox(
            child: CupertinoPicker.builder(
              scrollController: _agePickerCtrl,
              itemExtent: 46,
              diameterRatio: 1.4,
              squeeze: 1.2,
              useMagnifier: true,
              magnification: 1.15,
              onSelectedItemChanged: (index) {
                HapticFeedback.selectionClick();
                setState(() => _age = 12 + index);
              },
              childCount: 74,
              itemBuilder: (context, index) {
                final val = 12 + index;
                final bool isSelected = val == _age;
                return Center(
                  child: Text(
                    '$val tuổi',
                    style: TextStyle(
                      fontSize: isSelected ? 24 : 18,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w400,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderStep() {
    return _buildTemplate(
      icon: Icons.wc_rounded,
      title: 'Giới tính sinh học?',
      subtitle: 'Nhu cầu calo cơ thể khác biệt giữa nam và nữ',
      content: Row(
        children: [
          Expanded(
            child: _buildSelectCard(
              emoji: '👨',
              title: 'Nam giới',
              isSelected: _gender == 'MALE',
              onTap: () => setState(() => _gender = 'MALE'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSelectCard(
              emoji: '👩',
              title: 'Nữ giới',
              isSelected: _gender == 'FEMALE',
              onTap: () => setState(() => _gender = 'FEMALE'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeightStep() {
    return _buildTemplate(
      icon: Icons.height_rounded,
      title: 'Chiều cao của bạn?',
      subtitle: 'Cuộn bánh xe để chọn chiều cao chuẩn xác',
      content: Column(
        children: [
          _buildBigDisplayHeader(_heightCm.toStringAsFixed(0), 'cm'),
          const SizedBox(height: 24),
          _buildProIosPickerBox(
            child: CupertinoPicker.builder(
              scrollController: _heightPickerCtrl,
              itemExtent: 46,
              diameterRatio: 1.4,
              squeeze: 1.2,
              useMagnifier: true,
              magnification: 1.15,
              onSelectedItemChanged: (index) {
                HapticFeedback.selectionClick();
                setState(() => _heightCm = (130 + index).toDouble());
              },
              childCount: 91,
              itemBuilder: (context, index) {
                final val = 130 + index;
                final bool isSelected = val == _heightCm.round();
                return Center(
                  child: Text(
                    '$val cm',
                    style: TextStyle(
                      fontSize: isSelected ? 24 : 18,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w400,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentWeightStep() {
    return _buildTemplate(
      icon: Icons.monitor_weight_outlined,
      title: 'Cân nặng hiện tại của bạn?',
      subtitle: 'Cuộn cột bên trái cho số kg, bên phải cho số thập phân',
      content: Column(
        children: [
          _buildBigDisplayHeader(_weightKg.toStringAsFixed(1), 'kg'),
          const SizedBox(height: 24),
          _buildProIosDualWeightPicker(
            intController: _weightIntPickerCtrl,
            decController: _weightDecPickerCtrl,
            currentValue: _weightKg,
            onChanged: (newWeight) => setState(() => _weightKg = newWeight),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetWeightStep() {
    final diff = _targetWeightKg - _weightKg;
    final isLosing = diff < -0.1;
    final isGaining = diff > 0.1;

    return _buildTemplate(
      icon: Icons.flag_rounded,
      title: 'Mục tiêu cân nặng của bạn?',
      subtitle: 'Cuộn chọn cân nặng mục tiêu bạn mong muốn đạt được',
      content: Column(
        children: [
          _buildBigDisplayHeader(_targetWeightKg.toStringAsFixed(1), 'kg'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isLosing
                  ? const Color(0xFF0D9488).withValues(alpha: 0.15)
                  : isGaining
                      ? Colors.orange.withValues(alpha: 0.15)
                      : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLosing
                    ? const Color(0xFF2DD4BF)
                    : isGaining
                        ? Colors.orange
                        : const Color(0xFF334155),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLosing
                      ? Icons.trending_down
                      : isGaining
                          ? Icons.trending_up
                          : Icons.horizontal_rule,
                  color: isLosing
                      ? const Color(0xFF2DD4BF)
                      : isGaining
                          ? Colors.orange
                          : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isLosing
                      ? 'Mục tiêu giảm: ${(-diff).toStringAsFixed(1)} kg'
                      : isGaining
                          ? 'Mục tiêu tăng: ${diff.toStringAsFixed(1)} kg'
                          : 'Giữ nguyên cân nặng hiện tại',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isLosing
                        ? const Color(0xFF2DD4BF)
                        : isGaining
                            ? Colors.orange
                            : Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildProIosDualWeightPicker(
            intController: _targetWeightIntPickerCtrl,
            decController: _targetWeightDecPickerCtrl,
            currentValue: _targetWeightKg,
            onChanged: (newTarget) {
              setState(() {
                _targetWeightKg = newTarget;
                if (_targetWeightKg < _weightKg) {
                  _speedGoal = 'LOSE_WEIGHT';
                } else if (_targetWeightKg > _weightKg) {
                  _speedGoal = 'GAIN_WEIGHT';
                } else {
                  _speedGoal = 'MAINTAIN';
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedGoalStep() {
    final preview = _calculateNutritionPreview();
    final bool isLosing = _targetWeightKg < _weightKg - 0.1;
    final bool isGaining = _targetWeightKg > _weightKg + 0.1;

    return _buildTemplate(
      icon: Icons.speed_rounded,
      title: 'Chọn tốc độ đạt mục tiêu',
      subtitle: 'NutriTrack sẽ tính lượng Calo nạp vào hàng ngày tương ứng',
      content: Column(
        children: [
          if (isLosing) ...[
            _buildOptionTile('Giảm nhẹ nhàng (-300 kcal/ngày)', 'LOSE_WEIGHT_SLOW', '~0.3 kg / tuần', '🌿'),
            _buildOptionTile('Giảm tiêu chuẩn (-500 kcal/ngày)', 'LOSE_WEIGHT', '~0.5 kg / tuần (Khuyên dùng)', '🥗'),
            _buildOptionTile('Giảm nhanh cấp tốc (-700 kcal/ngày)', 'LOSE_WEIGHT_FAST', '~0.75 kg / tuần', '⚡'),
          ] else if (isGaining) ...[
            _buildOptionTile('Tăng cân nhẹ (+200 kcal/ngày)', 'GAIN_WEIGHT_SLOW', '~0.25 kg / tuần', '🥪'),
            _buildOptionTile('Tăng cơ chuẩn (+400 kcal/ngày)', 'GAIN_WEIGHT', '~0.5 kg / tuần (Khuyên dùng)', '💪'),
            _buildOptionTile('Tăng cân nhanh (+600 kcal/ngày)', 'GAIN_WEIGHT_FAST', '~0.75 kg / tuần', '🚀'),
          ] else ...[
            _buildOptionTile('Duy trì cân nặng hiện tại', 'MAINTAIN', 'Cân bằng Calo In = Calo Out', '⚖️'),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF0D9488), width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mức Calo mỗi ngày:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                    Text(
                      '${preview['calories']} kcal',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2DD4BF)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF334155), height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMacroTag('Carbs', '${preview['carbs']}g', Colors.amber),
                    _buildMacroTag('Protein', '${preview['protein']}g', Colors.lightBlue),
                    _buildMacroTag('Fat', '${preview['fat']}g', Colors.redAccent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyMeasurementsStep() {
    return _buildTemplate(
      icon: Icons.straighten_rounded,
      title: 'Số đo 3 vòng (cm)',
      subtitle: 'Không bắt buộc. Bạn có thể cập nhật sau trong mục Cá nhân',
      btnText: _isSaving ? 'Đang thiết lập...' : 'Hoàn tất & Bắt đầu 🚀',
      skipWidget: TextButton(
        onPressed: _isSaving ? null : _submitData,
        child: const Text('Bỏ qua số đo, bắt đầu ngay →', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      content: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF162032),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          children: [
            _buildMeasurementField('Vòng 1 (Ngực)', _bustController, Icons.accessibility_new_rounded),
            const SizedBox(height: 14),
            _buildMeasurementField('Vòng 2 (Eo)', _waistController, Icons.compress_rounded),
            const SizedBox(height: 14),
            _buildMeasurementField('Vòng 3 (Mông)', _hipsController, Icons.directions_run_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildBigDisplayHeader(String value, String unit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: Color(0xFF2DD4BF), letterSpacing: -1.5),
        ),
        const SizedBox(width: 8),
        Text(
          unit,
          style: const TextStyle(fontSize: 20, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildProIosPickerBox({required Widget child}) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF121826),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.5)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: const Color(0xFF2DD4BF).withValues(alpha: 0.4), width: 1.5),
                    bottom: BorderSide(color: const Color(0xFF2DD4BF).withValues(alpha: 0.4), width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          child,
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF121826),
                    const Color(0xFF121826).withValues(alpha: 0.0),
                    const Color(0xFF121826).withValues(alpha: 0.0),
                    const Color(0xFF121826),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProIosDualWeightPicker({
    required FixedExtentScrollController intController,
    required FixedExtentScrollController decController,
    required double currentValue,
    required Function(double) onChanged,
  }) {
    final int currentInt = currentValue.toInt();
    final int currentDec = ((currentValue % 1) * 10).round();

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF121826),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155).withValues(alpha: 0.5)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 20,
            right: 20,
            child: IgnorePointer(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: const Color(0xFF2DD4BF).withValues(alpha: 0.4), width: 1.5),
                    bottom: BorderSide(color: const Color(0xFF2DD4BF).withValues(alpha: 0.4), width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: CupertinoPicker.builder(
                  scrollController: intController,
                  itemExtent: 46,
                  diameterRatio: 1.4,
                  squeeze: 1.2,
                  useMagnifier: true,
                  magnification: 1.15,
                  onSelectedItemChanged: (index) {
                    HapticFeedback.selectionClick();
                    final int newInt = 30 + index;
                    onChanged(newInt + (currentDec / 10.0));
                  },
                  childCount: 131,
                  itemBuilder: (context, index) {
                    final val = 30 + index;
                    final bool isSelected = val == currentInt;
                    return Center(
                      child: Text(
                        '$val',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w400,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Text('.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2DD4BF))),
              Expanded(
                child: CupertinoPicker.builder(
                  scrollController: decController,
                  itemExtent: 46,
                  diameterRatio: 1.4,
                  squeeze: 1.2,
                  useMagnifier: true,
                  magnification: 1.15,
                  onSelectedItemChanged: (index) {
                    HapticFeedback.selectionClick();
                    onChanged(currentInt + (index / 10.0));
                  },
                  childCount: 10,
                  itemBuilder: (context, index) {
                    final bool isSelected = index == currentDec;
                    return Center(
                      child: Text(
                        '$index kg',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w400,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF121826),
                    const Color(0xFF121826).withValues(alpha: 0.0),
                    const Color(0xFF121826).withValues(alpha: 0.0),
                    const Color(0xFF121826),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplate({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget content,
    Widget? skipWidget,
    String btnText = 'Tiếp tục',
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF2DD4BF), size: 26),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8), height: 1.3)),
          const SizedBox(height: 20),
          Expanded(child: SingleChildScrollView(child: content)),
          if (skipWidget != null) ...[
            Center(child: skipWidget),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isSaving ? null : _nextPage,
              child: Text(btnText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(String title, String value, String subtitle, String icon) {
    final bool isSelected = _speedGoal == value;
    return InkWell(
      onTap: () => setState(() => _speedGoal = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D9488).withValues(alpha: 0.15) : const Color(0xFF162032),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF2DD4BF) : const Color(0xFF334155),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isSelected ? const Color(0xFF2DD4BF) : Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF2DD4BF), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroTag(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  Widget _buildSelectCard({
    required String emoji,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 36),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D9488).withValues(alpha: 0.15) : const Color(0xFF162032),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? const Color(0xFF2DD4BF) : const Color(0xFF334155), width: 2),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF2DD4BF) : Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementField(String label, TextEditingController controller, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        decoration: InputDecoration(
          icon: Icon(icon, color: const Color(0xFF0D9488), size: 22),
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          suffixText: 'cm',
          suffixStyle: const TextStyle(color: Color(0xFF2DD4BF), fontWeight: FontWeight.bold),
          border: InputBorder.none,
        ),
      ),
    );
  }
}