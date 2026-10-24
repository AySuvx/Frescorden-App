// Alimento ya clasificado del catálogo curado (ver PresetFoodLocalDataSource):
// empacados y graneles comunes del hogar colombiano (arroz, lentejas, agua
// embotellada, etc.) que el usuario puede elegir en PresetFoodPickerScreen
// en vez de llenar el formulario a mano o depender del reconocimiento por
// foto con IA — ese reconocimiento es poco confiable justo para este tipo
// de producto empacado genérico (ver gemini_product_recognition_data_source.dart).

import 'food_category.dart';

class PresetFood {
  final String name;
  final FoodCategory category;
  final String unit;

  const PresetFood({
    required this.name,
    required this.category,
    required this.unit,
  });
}
