import '../entities/food_category.dart';
import '../entities/preset_food.dart';

abstract class IPresetFoodRepository {
  /// Catálogo completo. PresetFoodPickerScreen filtra por categoría y por
  /// texto de búsqueda en memoria — la lista es pequeña (catálogo curado,
  /// no datos de usuario), no se justifica paginar ni filtrar en el origen.
  Future<List<PresetFood>> getAll();

  /// Atajo sobre [getAll] para la categoría elegida en CategoryPickerScreen.
  Future<List<PresetFood>> getByCategory(FoodCategory category);
}
