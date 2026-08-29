import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../diary/data/models/diary_entry_model.dart';
import '../../../diary/data/models/food_model.dart';
import '../../../diary/presentation/bloc/diary_bloc.dart';
import '../../../diary/presentation/bloc/diary_event.dart';

class CreateCustomFoodPage extends StatefulWidget {
  final dynamic repository;
  final DateTime? selectedDate;
  final String defaultMealType;
  final bool isReadOnly;
  final DiaryEntryModel? initialEntry;

  const CreateCustomFoodPage({
    super.key,
    this.repository,
    this.selectedDate,
    this.defaultMealType = 'BREAKFAST',
    this.isReadOnly = false,
    this.initialEntry,
  });

  @override
  State<CreateCustomFoodPage> createState() => _CreateCustomFoodPageState();
}

class _CreateCustomFoodPageState extends State<CreateCustomFoodPage>
    with SingleTickerProviderStateMixin {
  static final Map<String, Uint8List> _foodImageCache = {};

  final _apiClient = ApiClient();
  final _picker = ImagePicker();

  late AnimationController _laserController;

  Uint8List? _imageBytes;
  bool _isAnalyzing = false;
  bool _hasResult = false;
  bool _isSaving = false;

  int _stepIndex = 1;
  Timer? _stepTimer;

  late String _selectedMealType;

  String _foodName = '';
  int _healthScore = 7;
  int _calories = 0;
  String _portion = '100 g';
  double _carbsG = 0.0;
  double _proteinG = 0.0;
  double _fatG = 0.0;
  double _fiberG = 0.0;
  List<Map<String, dynamic>> _ingredients = [];

  static double _parseNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(val);
      if (m != null) return double.tryParse(m.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  static double _extractFiberFromData(dynamic data) {
    if (data == null) return 0.0;
    if (data is num) return data.toDouble();
    if (data is String) return _parseNum(data);

    if (data is Map) {
      for (final key in [
        'fiber', 'fiberG', 'dietaryFiber', 'totalFiber',
        'fiber_g', 'dietary_fiber', 'fiberPer100', 'fiberPerPortion',
        'chat_xo', 'chatXo', 'fiber_value'
      ]) {
        if (data[key] != null) {
          final res = _parseNum(data[key]);
          if (res > 0) return res;
        }
      }

      for (final subKey in ['micronutrients', 'nutrition', 'details', 'health', 'macro']) {
        if (data[subKey] != null && data[subKey] is Map) {
          final res = _extractFiberFromData(data[subKey]);
          if (res > 0) return res;
        }
      }
    }
    return 0.0;
  }

  double _extractGramsStrict(dynamic weightVal, dynamic portionVal) {
    if (weightVal != null) {
      final g = _parseNum(weightVal);
      if (g > 0) return g;
    }
    if (portionVal != null && portionVal is String) {
      final match = RegExp(r'(\d+(?:\.\d+)?)\s*(?:g|gam|gram)\b', caseSensitive: false).firstMatch(portionVal);
      if (match != null) {
        return double.tryParse(match.group(1)!) ?? 100.0;
      }
      final numMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(portionVal);
      if (numMatch != null) {
        final val = double.tryParse(numMatch.group(1)!) ?? 100.0;
        return val >= 5 ? val : 100.0;
      }
    }
    return 100.0;
  }

  void _recalculateTotalNutrition() {
    int totalCal = 0;
    double totalC = 0.0;
    double totalP = 0.0;
    double totalF = 0.0;
    double totalFib = 0.0;
    double totalGrams = 0.0;

    for (var item in _ingredients) {
      totalCal += (item['calories'] as num?)?.toInt() ?? _parseNum(item['calories']).round();
      totalC += _parseNum(item['carbs'] ?? item['carbsG']);
      totalP += _parseNum(item['protein'] ?? item['proteinG']);
      totalF += _parseNum(item['fat'] ?? item['fatG']);
      totalFib += _extractFiberFromData(item);
      totalGrams += _extractGramsStrict(item['weightG'], item['portion']);
    }

    setState(() {
      _calories = totalCal;
      _carbsG = totalC;
      _proteinG = totalP;
      _fatG = totalF;
      _fiberG = totalFib;
      if (totalGrams > 0) {
        _portion = '${totalGrams.round()} g';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _selectedMealType = widget.defaultMealType.isNotEmpty
        ? widget.defaultMealType
        : _detectMealTypeByTime();

    if (widget.initialEntry != null) {
      final entry = widget.initialEntry!;
      final food = entry.food;
      _foodName = food?.name ?? 'Món ăn';
      _selectedMealType = entry.mealType;

      _calories = entry.calculatedCalories > 0 ? entry.calculatedCalories : (food?.calories ?? 0);
      _carbsG = entry.calculatedCarbs > 0 ? entry.calculatedCarbs.toDouble() : (food?.carbsG ?? 0.0);
      _proteinG = entry.calculatedProtein > 0 ? entry.calculatedProtein.toDouble() : (food?.proteinG ?? 0.0);
      _fatG = entry.calculatedFat > 0 ? entry.calculatedFat.toDouble() : (food?.fatG ?? 0.0);
      _fiberG = food?.fiberG ?? 0.0;
      _portion = '${entry.quantity.toStringAsFixed(0)} g';

      final desc = food?.description ?? '';
      if (desc.isNotEmpty && (desc.startsWith('{') || desc.startsWith('['))) {
        try {
          final decoded = jsonDecode(desc);
          if (decoded is Map<String, dynamic>) {
            _healthScore = (decoded['healthScore'] as num?)?.toInt() ?? 7;
            if (decoded['portion'] != null) _portion = decoded['portion'].toString();

            final fiber = _extractFiberFromData(decoded);
            if (fiber > 0) _fiberG = fiber;

            if (decoded['ingredients'] != null && decoded['ingredients'] is List) {
              _ingredients = List<Map<String, dynamic>>.from(decoded['ingredients']);
            }
          }
        } catch (_) {}
      }

      final cacheKey = _foodName.trim().toLowerCase();
      if (_foodImageCache.containsKey(cacheKey)) {
        _imageBytes = _foodImageCache[cacheKey];
      }

      _hasResult = true;
    }
  }

  String _detectMealTypeByTime() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) return 'BREAKFAST';
    if (hour >= 11 && hour < 15) return 'LUNCH';
    if (hour >= 15 && hour < 21) return 'DINNER';
    return 'SNACK';
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _laserController.dispose();
    super.dispose();
  }

  void _startStepAnimation() {
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (!mounted) return;
      setState(() {
        _stepIndex = (_stepIndex % 3) + 1;
      });
    });
  }

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      setState(() {
        _imageBytes = bytes;
        _isAnalyzing = true;
        _hasResult = false;
        _stepIndex = 1;
      });

      _startStepAnimation();

      final base = ApiEndpoints.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
      final url = '$base/api/v1/foods/analyze-image';

      final response = await _apiClient.uploadBytes(
        url,
        bytes,
        picked.name,
        'image',
      );

      _stepTimer?.cancel();

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];

        final name = data['name']?.toString() ?? 'Món ăn nhận diện';
        final estimatedGrams = _parseNum(data['estimatedGramsInImage'] ?? data['grams'] ?? 250);
        final ratio = estimatedGrams / 100.0;

        final cal = (data['totalCalories'] as num?)?.toInt() ?? _parseNum(data['calories']).round();
        final c = _parseNum(data['totalCarbs'] ?? data['carbsG'] ?? data['carbs']);
        final p = _parseNum(data['totalProtein'] ?? data['proteinG'] ?? data['protein']);
        final f = _parseNum(data['totalFat'] ?? data['fatG'] ?? data['fat']);

        double fiber = _extractFiberFromData(data);
        if (fiber == 0.0 && data['fiberPer100'] != null) {
          fiber = _parseNum(data['fiberPer100']) * ratio;
        }

        List<Map<String, dynamic>> ingList = [];
        if (data['ingredients'] != null && data['ingredients'] is List) {
          ingList = (data['ingredients'] as List).map<Map<String, dynamic>>((e) {
            final weight = e['weightG'] ?? e['weight'] ?? e['grams'];
            final wG = _parseNum(weight);

            double fG = _extractFiberFromData(e);
            if (fG == 0.0) {
              final n = (e['name'] ?? '').toString().toLowerCase();
              final safeG = wG > 0 ? wG : 100.0;
              if (n.contains('khoai') || n.contains('bí đỏ') || n.contains('kabocha')) {
                fG = (safeG / 100.0) * 2.5;
              } else if (n.contains('cơm') || n.contains('gạo')) {
                fG = (safeG / 100.0) * 0.4;
              } else if (n.contains('rau') || n.contains('canh') || n.contains('cà chua')) {
                fG = (safeG / 100.0) * 1.2;
              }
            }

            return {
              'name': e['name']?.toString() ?? '',
              'weightG': wG > 0 ? wG : 100,
              'portion': e['portion']?.toString() ?? (weight != null ? '$weight g' : '100g'),
              'calories': (e['calories'] as num?)?.toInt() ?? _parseNum(e['calories']).round(),
              'carbs': _parseNum(e['carbsG'] ?? e['carbs']).toStringAsFixed(1),
              'protein': _parseNum(e['proteinG'] ?? e['protein']).toStringAsFixed(1),
              'fat': _parseNum(e['fatG'] ?? e['fat']).toStringAsFixed(1),
              'fiberG': fG,
              'fiber': fG,
            };
          }).toList();
        }

        final cacheKey = name.trim().toLowerCase();
        if (_imageBytes != null) {
          _foodImageCache[cacheKey] = _imageBytes!;
        }

        setState(() {
          _foodName = name;
          _healthScore = (data['healthScore'] as num?)?.toInt() ?? 7;
          _calories = cal;
          _carbsG = c;
          _proteinG = p;
          _fatG = f;
          _fiberG = fiber;
          _portion = '${estimatedGrams.round()} g';
          _ingredients = ingList;
          _isAnalyzing = false;
          _hasResult = true;
        });
      } else {
        throw response['message'] ?? 'Không có dữ liệu phản hồi từ AI';
      }
    } catch (e) {
      debugPrint('Lỗi AI Scan Food: $e');
      _stepTimer?.cancel();
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _hasResult = false;
        });
        AppToast.showError(
          context,
          'Không thể phân tích ảnh: $e. Vui lòng thử lại!',
          title: 'Lỗi nhận diện AI',
        );
      }
    }
  }

  void _showEditNutritionDialog(bool isDark) {
    if (widget.isReadOnly) return;

    final nameCtrl = TextEditingController(text: _foodName);
    final portionCtrl = TextEditingController(text: _portion);
    final calCtrl = TextEditingController(text: '$_calories');
    final carbsCtrl = TextEditingController(text: _carbsG.toStringAsFixed(1));
    final proteinCtrl = TextEditingController(text: _proteinG.toStringAsFixed(1));
    final fatCtrl = TextEditingController(text: _fatG.toStringAsFixed(1));
    final fiberCtrl = TextEditingController(text: _fiberG.toStringAsFixed(1));

    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color inputFill = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Chỉnh sửa thông số món ăn',
          style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Tên món ăn',
                  filled: true,
                  fillColor: inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: portionCtrl,
                      style: GoogleFonts.plusJakartaSans(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Khẩu phần',
                        filled: true,
                        fillColor: inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: calCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Calo (kcal)',
                        filled: true,
                        fillColor: inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: carbsCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFBBF24), fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Carbs (g)',
                        filled: true,
                        fillColor: inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: proteinCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFFF87171), fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Protein (g)',
                        filled: true,
                        fillColor: inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF34D399), fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Fat (g)',
                        filled: true,
                        fillColor: inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fiberCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.plusJakartaSans(color: const Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Chất xơ (g)',
                  filled: true,
                  fillColor: inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {
                _foodName = nameCtrl.text.trim();
                _portion = portionCtrl.text.trim();
                _calories = int.tryParse(calCtrl.text) ?? _calories;
                _carbsG = double.tryParse(carbsCtrl.text) ?? _carbsG;
                _proteinG = double.tryParse(proteinCtrl.text) ?? _proteinG;
                _fatG = double.tryParse(fatCtrl.text) ?? _fatG;
                _fiberG = double.tryParse(fiberCtrl.text) ?? _fiberG;
              });
              Navigator.pop(ctx);
              AppToast.showSuccess(context, 'Đã cập nhật thông số!');
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  void _showAddIngredientDialog(bool isDark) {
    if (widget.isReadOnly) return;

    final ingNameCtrl = TextEditingController();
    final ingPortionCtrl = TextEditingController(text: '50 g');
    final ingCalCtrl = TextEditingController(text: '80');
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color inputFill = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Thêm thành phần món',
          style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ingNameCtrl,
              style: GoogleFonts.plusJakartaSans(color: textColor),
              decoration: InputDecoration(
                labelText: 'Tên nguyên liệu (VD: Trứng gà, Rau xanh...)',
                filled: true,
                fillColor: inputFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ingPortionCtrl,
                    style: GoogleFonts.plusJakartaSans(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Định lượng',
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: ingCalCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Calo ước tính',
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (ingNameCtrl.text.trim().isNotEmpty) {
                final addCal = int.tryParse(ingCalCtrl.text) ?? 50;
                final addGram = _extractGramsStrict(null, ingPortionCtrl.text.trim());

                setState(() {
                  _ingredients.add({
                    'name': ingNameCtrl.text.trim(),
                    'portion': ingPortionCtrl.text.trim(),
                    'weightG': addGram,
                    'calories': addCal,
                    'carbs': '0.0',
                    'protein': '0.0',
                    'fat': '0.0',
                    'fiberG': 0.0,
                    'fiber': 0.0,
                  });
                });
                _recalculateTotalNutrition();
                Navigator.pop(ctx);
                AppToast.showSuccess(context, 'Đã thêm thành phần mới!');
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _showEditSingleIngredientDialog(int index, bool isDark) {
  if (widget.isReadOnly) return;

  final item = _ingredients[index];
  final nameCtrl = TextEditingController(text: item['name'] ?? '');

  final double originalGram = _extractGramsStrict(item['weightG'], item['portion']);
  final gramCtrl = TextEditingController(text: originalGram.round().toString());

  final double originalCal = _parseNum(item['calories']);
  final calCtrl = TextEditingController(text: originalCal.round().toString());

  final double originalCarbs = _parseNum(item['carbs'] ?? item['carbsG']);
  final double originalProtein = _parseNum(item['protein'] ?? item['proteinG']);
  final double originalFat = _parseNum(item['fat'] ?? item['fatG']);

  double rawFiber = _extractFiberFromData(item);
  if (rawFiber == 0.0) {
    final n = (item['name'] ?? '').toString().toLowerCase();
    if (n.contains('khoai') || n.contains('bí đỏ') || n.contains('kabocha')) {
      rawFiber = (originalGram / 100.0) * 2.5;
    } else if (n.contains('cơm') || n.contains('gạo')) {
      rawFiber = (originalGram / 100.0) * 0.4;
    } else if (n.contains('rau') || n.contains('canh') || n.contains('cà chua')) {
      rawFiber = (originalGram / 100.0) * 1.2;
    }
  }
  final double originalFiber = rawFiber;
  double currentFiber = originalFiber;

  final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
  final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
  final Color inputFill = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderColor),
      ),
      title: Text(
        'Chỉnh sửa thành phần',
        style: GoogleFonts.plusJakartaSans(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Tên thành phần',
                  filled: true,
                  fillColor: inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: gramCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Khối lượng',
                        suffixText: 'g',
                        suffixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                        filled: true,
                        fillColor: inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) {
                        final newG = double.tryParse(val) ?? originalGram;
                        if (originalGram > 0) {
                          final ratio = newG / originalGram;
                          setDialogState(() {
                            calCtrl.text = (originalCal * ratio).round().toString();
                            currentFiber = originalFiber * ratio;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: calCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Calo',
                        suffixText: 'kcal',
                        suffixStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                        filled: true,
                        fillColor: inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'Hủy',
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            final newName = nameCtrl.text.trim();
            final newGrams = double.tryParse(gramCtrl.text) ?? originalGram;
            final newCal = int.tryParse(calCtrl.text) ?? originalCal.round();

            if (newName.isNotEmpty) {
              final ratio = originalGram > 0 ? (newGrams / originalGram) : 1.0;
              final newFiber = currentFiber;

              _ingredients[index] = {
                ...item,
                'name': newName,
                'weightG': newGrams,
                'portion': '${newGrams.round()}g',
                'calories': newCal,
                'carbs': (originalCarbs * ratio).toStringAsFixed(1),
                'protein': (originalProtein * ratio).toStringAsFixed(1),
                'fat': (originalFat * ratio).toStringAsFixed(1),
                'fiberG': newFiber,
                'fiber': newFiber,
                'dietaryFiber': newFiber,
                'totalFiber': newFiber,
              };

              _recalculateTotalNutrition();
              Navigator.pop(ctx);
              AppToast.showSuccess(context, 'Đã cập nhật $newName!');
            }
          },
          child: Text(
            'Cập nhật',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

  Future<void> _saveDirectlyToDiary() async {
    if (_isSaving || widget.isReadOnly) return;
    setState(() => _isSaving = true);

    final dateTarget = widget.selectedDate ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(dateTarget);

    final rawGrams = _parseNum(_portion);
    final double safeGrams = rawGrams > 0 ? rawGrams : 55.0;

    final Map<String, dynamic> metadata = {
      'healthScore': _healthScore,
      'portion': _portion,
      'totalGrams': safeGrams,
      'totalCalories': _calories,
      'totalCarbs': _carbsG,
      'totalProtein': _proteinG,
      'totalFat': _fatG,
      'totalFiber': _fiberG,
      'fiberG': _fiberG,
      'dietaryFiber': _fiberG,
      'ingredients': _ingredients,
    };

    try {
      final createFoodRes = await widget.repository.apiClient.post(ApiEndpoints.customFoods, {
        'name': _foodName.trim().isNotEmpty ? _foodName.trim() : "Món ăn nhận diện AI",
        'calories': _calories,
        'carbsG': _carbsG,
        'proteinG': _proteinG,
        'fatG': _fatG,
        'fiberG': _fiberG,
        'servingSizeWeight': safeGrams,
        'servingSizeUnit': 'g',
        'description': jsonEncode(metadata),
      });

      final newFoodData = createFoodRes['data'];
      final String foodId = newFoodData?['id'] ?? '';

      if (foodId.isEmpty) {
        throw Exception('Không nhận được mã món ăn từ hệ thống');
      }

      final entry = DiaryEntryModel(
        id: '',
        foodId: foodId,
        mealType: _selectedMealType,
        quantity: safeGrams,
        date: dateStr,
        calculatedCalories: _calories,
        calculatedCarbs: _carbsG,
        calculatedProtein: _proteinG,
        calculatedFat: _fatG,
        calculatedFiber: _fiberG,
        food: FoodModel.fromJson(newFoodData),
      );

      await widget.repository.addDiaryEntry(entry);

      if (!mounted) return;
      context.read<DiaryBloc>().add(LoadDailyDiary(dateStr: dateStr));
      AppToast.showSuccess(context, 'Đã lưu "$_foodName" ($_calories kcal) thành công!');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e, title: 'Lỗi lưu món');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _getMealName(String mealType) {
    switch (mealType) {
      case 'BREAKFAST': return 'Bữa sáng';
      case 'LUNCH': return 'Bữa trưa';
      case 'DINNER': return 'Bữa tối';
      case 'SNACK': return 'Bữa phụ';
      default: return 'Bữa ăn';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        if (_isAnalyzing) {
          return _buildScanningScreen(isDark);
        }
        if (_hasResult) {
          return _buildResultScreen(isDark);
        }
        return _buildInitialPickScreen(isDark);
      },
    );
  }

  Widget _buildInitialPickScreen(bool isDark) {
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chụp ảnh món ăn',
          style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF10B981), size: 48),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Phân tích Calo qua ảnh',
                    style: GoogleFonts.plusJakartaSans(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chụp hoặc chọn ảnh món ăn để AI nhận diện toàn bộ nguyên liệu, ước tính tổng calo và ghi thẳng vào nhật ký.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(color: subColor, fontSize: 13.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text('Mở Camera chụp ngay', style: GoogleFonts.plusJakartaSans(fontSize: 15.5, fontWeight: FontWeight.bold)),
              onPressed: () => _pickAndAnalyzeImage(ImageSource.camera),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: BorderSide(color: borderColor, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981)),
              label: Text('Chọn từ thư viện ảnh', style: GoogleFonts.plusJakartaSans(fontSize: 15.5, fontWeight: FontWeight.bold)),
              onPressed: () => _pickAndAnalyzeImage(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningScreen(bool isDark) {
    final Color bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final Color cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const Color primaryColor = Color(0xFF10B981);

    final List<String> steps = [
      'Phân tích cấu trúc món ăn',
      'Nhận diện nguyên liệu & thành phần',
      'Tính toán dinh dưỡng & Calo',
    ];

    String scanStatusText;
    switch (_stepIndex) {
      case 1:
        scanStatusText = 'Đang nhận diện khẩu phần...';
        break;
      case 2:
        scanStatusText = 'Đang bóc tách thành phần...';
        break;
      case 3:
      default:
        scanStatusText = 'Đang tính toán Calo & Macro...';
        break;
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: primaryColor, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI Scan Vision',
                    style: GoogleFonts.plusJakartaSans(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                flex: 4,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: _imageBytes != null
                                  ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                                  : Container(color: cardBg),
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.1),
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.6),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _laserController,
                              builder: (context, _) {
                                return Positioned(
                                  top: 15 + (_laserController.value * 270),
                                  left: 0,
                                  right: 0,
                                  child: Column(
                                    children: [
                                      Container(
                                        height: 2.0,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              primaryColor.withValues(alpha: 0.0),
                                              primaryColor,
                                              Colors.white,
                                              primaryColor,
                                              primaryColor.withValues(alpha: 0.0),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryColor.withValues(alpha: 0.8),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        height: 20,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              primaryColor.withValues(alpha: 0.2),
                                              primaryColor.withValues(alpha: 0.0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              bottom: 16,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: primaryColor,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: primaryColor.withValues(alpha: 0.8),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 300),
                                          child: Text(
                                            scanStatusText,
                                            key: ValueKey<String>(scanStatusText),
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(steps.length, (index) {
                      final int stepNum = index + 1;
                      final bool isDone = stepNum < _stepIndex;
                      final bool isCurrent = stepNum == _stepIndex;

                      return Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDone
                                  ? primaryColor
                                  : (isCurrent
                                      ? primaryColor.withValues(alpha: 0.15)
                                      : Colors.transparent),
                              border: Border.all(
                                color: isDone || isCurrent
                                    ? primaryColor
                                    : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: isDone
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                  : (isCurrent
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: primaryColor,
                                          ),
                                        )
                                      : Text(
                                          '$stepNum',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: subColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              steps[index],
                              style: GoogleFonts.plusJakartaSans(
                                color: isCurrent
                                    ? primaryColor
                                    : (isDone ? textColor : subColor),
                                fontSize: 14.5,
                                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_clock_rounded, size: 14, color: subColor),
                  const SizedBox(width: 6),
                  Text(
                    'Vui lòng không đóng ứng dụng hoặc khoá thiết bị',
                    style: GoogleFonts.plusJakartaSans(
                      color: subColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultScreen(bool isDark) {
    final nowTimeStr = DateFormat('HH:mm').format(DateTime.now());
    final carbsCal = _carbsG * 4;
    final proteinCal = _proteinG * 4;
    final fatCal = _fatG * 9;
    final totalCalCalc = (carbsCal + proteinCal + fatCal) == 0 ? 1.0 : (carbsCal + proteinCal + fatCal);

    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color subCardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final int fiberPercent = ((_fiberG / 25.0) * 100).round();
    final double fiberProgress = (_fiberG / 25.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isReadOnly ? 'Chi Tiết Món Ăn' : 'Kết Quả Nhận Diện AI',
          style: GoogleFonts.plusJakartaSans(color: textColor, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          if (!widget.isReadOnly) ...[
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_note_rounded, color: Color(0xFF10B981), size: 22),
              ),
              tooltip: 'Chỉnh sửa kết quả',
              onPressed: () => _showEditNutritionDialog(isDark),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, widget.isReadOnly ? 30 : 110),
            children: [
              if (!widget.isReadOnly) ...[
                Container(
                  padding: const EdgeInsets.all(14),
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
                            'Lưu vào bữa ăn:',
                            style: GoogleFonts.plusJakartaSans(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getMealName(_selectedMealType),
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF10B981),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 1. HERO HEADER
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_imageBytes != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            child: Image.memory(
                              _imageBytes!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 14,
                            right: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.favorite_rounded, color: Color(0xFFEF4444), size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Sức Khỏe: $_healthScore/10',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 12,
                            left: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    'AI Vision Verified',
                                    style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ƯỚC TÍNH LÚC $nowTimeStr',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF10B981),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: subCardBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _portion,
                                  style: GoogleFonts.plusJakartaSans(color: subTextColor, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _foodName,
                            style: GoogleFonts.plusJakartaSans(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. CARD NĂNG LƯỢNG & TỶ LỆ MACRO (3 MACRO CHÍNH)
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: widget.isReadOnly ? null : () => _showEditNutritionDialog(isDark),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Tổng Năng Lượng',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: subTextColor,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (!widget.isReadOnly) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.edit_rounded, size: 14, color: subTextColor),
                                  ],
                                ],
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$_calories',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: textColor,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'kcal',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF10B981),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 8,
                              child: Row(
                                children: [
                                  Expanded(flex: ((carbsCal / totalCalCalc) * 100).toInt().clamp(1, 100), child: Container(color: const Color(0xFFF59E0B))),
                                  const SizedBox(width: 2),
                                  Expanded(flex: ((proteinCal / totalCalCalc) * 100).toInt().clamp(1, 100), child: Container(color: const Color(0xFFEF4444))),
                                  const SizedBox(width: 2),
                                  Expanded(flex: ((fatCal / totalCalCalc) * 100).toInt().clamp(1, 100), child: Container(color: const Color(0xFF10B981))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildMacroMetricCard('Tinh bột', '${_carbsG.toStringAsFixed(0)}g', '${((carbsCal / totalCalCalc) * 100).round()}%', const Color(0xFFF59E0B), isDark),
                              const SizedBox(width: 8),
                              _buildMacroMetricCard('Chất đạm', '${_proteinG.toStringAsFixed(0)}g', '${((proteinCal / totalCalCalc) * 100).round()}%', const Color(0xFFEF4444), isDark),
                              const SizedBox(width: 8),
                              _buildMacroMetricCard('Chất béo', '${_fatG.toStringAsFixed(0)}g', '${((fatCal / totalCalCalc) * 100).round()}%', const Color(0xFF10B981), isDark),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
                            const SizedBox(height: 14),

              // 3. CARD BÓC TÁCH THÀNH PHẦN CON
              if (_ingredients.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Thành phần chi tiết',
                            style: GoogleFonts.plusJakartaSans(
                              color: textColor,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (!widget.isReadOnly)
                            InkWell(
                              onTap: () => _showAddIngredientDialog(isDark),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Thêm món',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFF10B981),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(_ingredients.length, (index) {
                        final item = _ingredients[index];
                        final String name = item['name'] ?? '';
                        final String portion = item['portion']?.toString() ?? '';
                        final int cal = (item['calories'] as num?)?.toInt() ?? _parseNum(item['calories']).round();

                        final double itemCarbs = _parseNum(item['carbs'] ?? item['carbsG']);
                        final double itemProtein = _parseNum(item['protein'] ?? item['proteinG']);
                        final double itemFat = _parseNum(item['fat'] ?? item['fatG']);
                        final double itemFiber = _extractFiberFromData(item);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: subCardBg,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: InkWell(
                            onTap: widget.isReadOnly ? null : () => _showEditSingleIngredientDialog(index, isDark),
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: textColor,
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '$portion • $cal kcal',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: subTextColor,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            if (itemCarbs > 0)
                                              _buildMiniMacroDot('Carb', '${itemCarbs.toStringAsFixed(1)}g', const Color(0xFFF59E0B), isDark),
                                            if (itemProtein > 0)
                                              _buildMiniMacroDot('Đạm', '${itemProtein.toStringAsFixed(1)}g', const Color(0xFFEF4444), isDark),
                                            if (itemFat > 0)
                                              _buildMiniMacroDot('Béo', '${itemFat.toStringAsFixed(1)}g', const Color(0xFF10B981), isDark),
                                            if (itemFiber > 0)
                                              _buildMiniMacroDot('Xơ', '${itemFiber.toStringAsFixed(1)}g', const Color(0xFF8B5CF6), isDark),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!widget.isReadOnly)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(Icons.close_rounded, color: subTextColor, size: 18),
                                      onPressed: () {
                                        _ingredients.removeAt(index);
                                        _recalculateTotalNutrition();
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              const SizedBox(height: 14),

              // 4. CARD CHẤT XƠ (MÀU TÍM)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chất Xơ & Vi Chất',
                          style: GoogleFonts.plusJakartaSans(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_fiberG % 1 == 0 ? _fiberG.toInt() : _fiberG.toStringAsFixed(1)} g chất xơ',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF8B5CF6),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: fiberProgress,
                        backgroundColor: subCardBg,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Cung cấp ~$fiberPercent% nhu cầu chất xơ khuyến nghị hàng ngày, hỗ trợ tiêu hóa tốt.',
                      style: GoogleFonts.plusJakartaSans(color: subTextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),

          if (!widget.isReadOnly)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: _isSaving ? null : _saveDirectlyToDiary,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bookmark_add_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'LƯU VÀO ${_getMealName(_selectedMealType).toUpperCase()}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 15.5, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniMacroDot(String label, String value, Color dotColor, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $value',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMealChip(String type, String label, bool isDark) {
    final isSelected = _selectedMealType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMealType = type;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF10B981)
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMacroMetricCard(String title, String grams, String percent, Color accentColor, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              grams,
              style: GoogleFonts.plusJakartaSans(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              percent,
              style: GoogleFonts.plusJakartaSans(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScannerCornerPainter extends CustomPainter {
  final Color cornerColor;

  ScannerCornerPainter({this.cornerColor = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final thinPaint = Paint()
      ..color = cornerColor.withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final RRect fullRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(24),
    );
    canvas.drawRRect(fullRRect, thinPaint);

    final paint = Paint()
      ..color = cornerColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;
    const radius = 24.0;

    final pathTL = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, radius)
      ..arcToPoint(const Offset(radius, 0), radius: const Radius.circular(radius))
      ..lineTo(cornerLength, 0);
    canvas.drawPath(pathTL, paint);

    final pathTR = Path()
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(Offset(size.width, radius), radius: const Radius.circular(radius))
      ..lineTo(size.width, cornerLength);
    canvas.drawPath(pathTR, paint);

    final pathBL = Path()
      ..moveTo(0, size.height - cornerLength)
      ..lineTo(0, size.height - radius)
      ..arcToPoint(Offset(radius, size.height), radius: const Radius.circular(radius))
      ..lineTo(cornerLength, size.height);
    canvas.drawPath(pathBL, paint);

    final pathBR = Path()
      ..moveTo(size.width - cornerLength, size.height)
      ..lineTo(size.width - radius, size.height)
      ..arcToPoint(Offset(size.width, size.height - radius), radius: const Radius.circular(radius))
      ..lineTo(size.width, cornerLength);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant ScannerCornerPainter oldDelegate) =>
      oldDelegate.cornerColor != cornerColor;
}