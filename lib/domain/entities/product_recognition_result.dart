import 'food_category.dart';

/// Resultado de identificar un producto a partir de una foto (ver
/// IProductRecognitionRepository). Campos ya resueltos a tipos de dominio
/// (FoodCategory, no el string crudo que devuelve el modelo).
class ProductRecognitionResult {
  final String name;
  final FoodCategory category;
  final String unit;

  const ProductRecognitionResult({
    required this.name,
    required this.category,
    required this.unit,
  });
}
