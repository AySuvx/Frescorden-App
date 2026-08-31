// lib/data/models/recipe_model.dart
//
// Modelo de datos: traduce entre el JSON de assets/data/recetas.json y la
// entidad de dominio [Recipe]. Mismo rol que ProductModel para Product.

import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_ingredient.dart';

class RecipeModel {
  static Recipe fromJson(Map<String, dynamic> json) {
    final ingredientesJson = (json['ingredientes'] as List<dynamic>? ?? []);
    return Recipe(
      id: json['id'] as String,
      name: json['nombre'] as String,
      servings: (json['personas'] as num?)?.toInt() ?? 1,
      imagePath: json['imagen'] as String,
      ingredients: ingredientesJson
          .map(
            (i) => RecipeIngredient(
              name: i['nombre'] as String,
              quantity: (i['cantidad'] as num?) ?? 0,
              unit: i['unidad'] as String? ?? '',
            ),
          )
          .toList(),
      steps: (json['pasos'] as List<dynamic>? ?? [])
          .map((p) => p.toString())
          .toList(),
    );
  }
}
