import 'food_model.dart';

class MealLogModel {
  final String id;
  final String foodId;
  final String mealType;
  final double quantity;
  final int totalCalories;
  final double totalCarbsG;
  final double totalProteinG;
  final double totalFatG;
  final FoodModel? food;

  MealLogModel({
    required this.id,
    required this.foodId,
    required this.mealType,
    required this.quantity,
    required this.totalCalories,
    required this.totalCarbsG,
    required this.totalProteinG,
    required this.totalFatG,
    this.food,
  });

  factory MealLogModel.fromJson(Map<String, dynamic> json) {
    return MealLogModel(
      id: json['id'] ?? '',
      foodId: json['foodId'] ?? '',
      mealType: json['mealType'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      totalCalories: json['totalCalories'] ?? 0,
      totalCarbsG: (json['totalCarbsG'] as num?)?.toDouble() ?? 0.0,
      totalProteinG: (json['totalProteinG'] as num?)?.toDouble() ?? 0.0,
      totalFatG: (json['totalFatG'] as num?)?.toDouble() ?? 0.0,
      food: json['food'] != null ? FoodModel.fromJson(json['food']) : null,
    );
  }
}