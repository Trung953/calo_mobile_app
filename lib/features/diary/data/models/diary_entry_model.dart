import 'food_model.dart';

class CalorieSummaryModel {
  final int targetCalories;
  final int totalCalories;
  final int totalBurnedCalories;
  final int remainingCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final num totalFiber;

  CalorieSummaryModel({
    required this.targetCalories,
    required this.totalCalories,
    this.totalBurnedCalories = 0,
    required this.remainingCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    this.targetProtein = 120.0,
    this.targetCarbs = 250.0,
    this.targetFat = 60.0,
    this.totalFiber = 0,
  });

  factory CalorieSummaryModel.fromJson(Map<String, dynamic> json) {
    return CalorieSummaryModel(
      targetCalories: (json['targetCalories'] as num?)?.toInt() ?? 2000,
      totalCalories: (json['totalCalories'] as num?)?.toInt() ?? 0,
      totalBurnedCalories: (json['totalBurnedCalories'] as num?)?.toInt() ?? 0,
      remainingCalories: (json['remainingCalories'] as num?)?.toInt() ?? 2000,
      totalProtein: (json['totalProtein'] as num?)?.toDouble() ?? 0.0,
      totalCarbs: (json['totalCarbs'] as num?)?.toDouble() ?? 0.0,
      totalFat: (json['totalFat'] as num?)?.toDouble() ?? 0.0,
      totalFiber: (json['totalFiber'] as num?)?.toDouble() ?? 0.0,
      targetProtein: (json['targetProtein'] as num?)?.toDouble() ?? 120.0,
      targetCarbs: (json['targetCarbs'] as num?)?.toDouble() ?? 250.0,
      targetFat: (json['targetFat'] as num?)?.toDouble() ?? 60.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targetCalories': targetCalories,
      'totalCalories': totalCalories,
      'totalBurnedCalories': totalBurnedCalories,
      'remainingCalories': remainingCalories,
      'totalProtein': totalProtein,
      'totalCarbs': totalCarbs,
      'totalFat': totalFat,
      'totalFiber': totalFiber,
      'targetProtein': targetProtein,
      'targetCarbs': targetCarbs,
      'targetFat': targetFat,
    };
  }
}

class DiaryEntryModel {
  final String id;
  final String foodId;
  final String mealType;
  final double quantity;
  final String date;
  final int calculatedCalories;
  final double calculatedProtein;
  final double calculatedCarbs;
  final double calculatedFat;
  final double? calculatedFiber;
  final FoodModel? food;

  DiaryEntryModel({
    required this.id,
    required this.foodId,
    required this.mealType,
    required this.quantity,
    required this.date,
    required this.calculatedCalories,
    required this.calculatedProtein,
    required this.calculatedCarbs,
    required this.calculatedFat,
    this.calculatedFiber = 0.0,
    this.food,
  });

  factory DiaryEntryModel.fromJson(Map<String, dynamic> json) {
    return DiaryEntryModel(
      id: json['id'] ?? '',
      foodId: json['foodId'] ?? '',
      mealType: json['mealType'] ?? 'BREAKFAST',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 100.0,
      date: json['date'] ?? json['loggedDate']?.toString().split('T')[0] ?? '',
      calculatedCalories: (json['calculatedCalories'] as num?)?.toInt() ?? 0,
      calculatedProtein: (json['calculatedProtein'] as num?)?.toDouble() ?? 0.0,
      calculatedCarbs: (json['calculatedCarbs'] as num?)?.toDouble() ?? 0.0,
      calculatedFat: (json['calculatedFat'] as num?)?.toDouble() ?? 0.0,
      calculatedFiber: (json['calculatedFiber'] as num?)?.toDouble() ?? 0.0, // <- Đã sửa đúng chính tả
      food: json['food'] != null ? FoodModel.fromJson(json['food']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'foodId': foodId,
      'mealType': mealType,
      'quantity': quantity,
      'date': date,
      'calculatedCalories': calculatedCalories,
      'calculatedProtein': calculatedProtein,
      'calculatedCarbs': calculatedCarbs,
      'calculatedFat': calculatedFat,
      'calculatedFiber': calculatedFiber,
      if (food != null) 'food': food!.toJson(),
    };
  }
}