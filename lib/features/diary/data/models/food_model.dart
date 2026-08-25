import 'dart:convert';

class FoodModel {
  final String id;
  final String name;
  final int calories;
  final double carbsG;
  final double proteinG;
  final double fatG;
  final double fiberG;
  final double? servingSizeWeight;
  final String? servingSizeUnit;
  final String? description;
  final bool isCustom;

  FoodModel({
    required this.id,
    required this.name,
    required this.calories,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    this.fiberG = 0.0,
    this.servingSizeWeight,
    this.servingSizeUnit,
    this.description,
    this.isCustom = false,
  });

  static double _parseNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(val);
      if (match != null) return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  static double _extractFiberRecursively(dynamic data) {
    if (data == null) return 0.0;
    if (data is num) return data.toDouble();
    if (data is String) return _parseNum(data);

    if (data is Map) {
      for (final key in [
        'fiber',
        'fiberG',
        'dietaryFiber',
        'totalFiber',
        'fiber_g',
        'dietary_fiber',
        'fiberPer100',
        'fiberPer100g',
        'chat_xo',
        'chatXo'
      ]) {
        if (data[key] != null) {
          final res = _parseNum(data[key]);
          if (res > 0) return res;
        }
      }

      for (final subKey in [
        'micronutrients',
        'nutrition',
        'details',
        'health',
        'macro'
      ]) {
        if (data[subKey] != null && data[subKey] is Map) {
          final res = _extractFiberRecursively(data[subKey]);
          if (res > 0) return res;
        }
      }
    }
    return 0.0;
  }

  factory FoodModel.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? 'Món ăn';
    final desc = json['description']?.toString();

    // 1. Quét calo: hỗ trợ cả calories và caloriesPer100g
    final int cal = (json['calories'] as num?)?.toInt() ??
        (json['caloriesPer100g'] as num?)?.toInt() ??
        _parseNum(json['calorie']).round();

    // 2. Quét Macros: hỗ trợ cả đuôi G lẫn đuôi Per100g
    final double carbs = _parseNum(
        json['carbsG'] ?? json['carbsPer100g'] ?? json['carbs'] ?? json['carbohydrates']);
    final double protein = _parseNum(
        json['proteinG'] ?? json['proteinPer100g'] ?? json['protein']);
    final double fat = _parseNum(
        json['fatG'] ?? json['fatPer100g'] ?? json['fat'] ?? json['totalFat']);

    // 3. Quét chất xơ từ JSON gốc
    double extractedFiber = _extractFiberRecursively(json);

    // 4. Nếu chưa có, giải mã từ JSON lồng bên trong description
    if (extractedFiber == 0.0 && desc != null && desc.isNotEmpty) {
      if (desc.startsWith('{') || desc.startsWith('[')) {
        try {
          final decoded = jsonDecode(desc);
          extractedFiber = _extractFiberRecursively(decoded);
        } catch (_) {}
      }

      // Quét text nếu description lưu chuỗi định dạng
      if (extractedFiber == 0.0) {
        final match = RegExp(
          r'(\d+(?:\.\d+)?)\s*(?:g|gram)?\s*(?:chất xơ|fiber)',
          caseSensitive: false,
        ).firstMatch(desc);
        if (match != null) {
          extractedFiber = double.tryParse(match.group(1)!) ?? 0.0;
        }
      }
    }

    return FoodModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: name,
      calories: cal,
      carbsG: carbs,
      proteinG: protein,
      fatG: fat,
      fiberG: extractedFiber,
      servingSizeWeight: _parseNum(json['servingSizeWeight'] ??
          json['defaultServing'] ??
          json['servingWeight'] ??
          100.0),
      servingSizeUnit: json['servingSizeUnit']?.toString() ??
          json['servingUnit']?.toString() ??
          'g',
      description: desc,
      isCustom: json['isCustom'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'carbsG': carbsG,
      'proteinG': proteinG,
      'fatG': fatG,
      'fiberG': fiberG,
      'servingSizeWeight': servingSizeWeight,
      'servingSizeUnit': servingSizeUnit,
      'description': description,
      'isCustom': isCustom,
    };
  }
}