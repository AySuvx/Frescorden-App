import '../../domain/entities/food_category.dart';
import '../../domain/entities/preset_food.dart';

class PresetFoodModel extends PresetFood {
  const PresetFoodModel({
    required super.name,
    required super.category,
    required super.unit,
  });

  factory PresetFoodModel.fromJson(Map<String, dynamic> json) {
    return PresetFoodModel(
      name: json['name'] as String,
      category: FoodCategory.fromName(json['category'] as String?),
      unit: json['unit'] as String,
    );
  }
}
