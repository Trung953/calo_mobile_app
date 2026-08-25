class DiarySummaryModel {
  final int totalCalories;
  final int targetCalories;
  final double totalCarbs;
  final double targetCarbs;
  final double totalProtein;
  final double targetProtein;
  final double totalFat;
  final double targetFat;

  const DiarySummaryModel({
    this.totalCalories = 0,
    this.targetCalories = 2000,
    this.totalCarbs = 0.0,
    this.targetCarbs = 250.0,
    this.totalProtein = 0.0,
    this.targetProtein = 100.0,
    this.totalFat = 0.0,
    this.targetFat = 65.0,
  });

  factory DiarySummaryModel.fromJson(Map<String, dynamic> json) {
    return DiarySummaryModel(
      totalCalories: (json['totalCalories'] as num?)?.toInt() ?? 0,
      targetCalories: (json['targetCalories'] as num?)?.toInt() ?? 2000,
      totalCarbs: (json['totalCarbs'] as num?)?.toDouble() ?? 0.0,
      targetCarbs: (json['targetCarbs'] as num?)?.toDouble() ?? 250.0,
      totalProtein: (json['totalProtein'] as num?)?.toDouble() ?? 0.0,
      targetProtein: (json['targetProtein'] as num?)?.toDouble() ?? 100.0,
      totalFat: (json['totalFat'] as num?)?.toDouble() ?? 0.0,
      targetFat: (json['targetFat'] as num?)?.toDouble() ?? 65.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalCalories': totalCalories,
      'targetCalories': targetCalories,
      'totalCarbs': totalCarbs,
      'targetCarbs': targetCarbs,
      'totalProtein': totalProtein,
      'targetProtein': targetProtein,
      'totalFat': totalFat,
      'targetFat': targetFat,
    };
  }
}