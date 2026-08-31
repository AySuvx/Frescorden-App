// lib/domain/entities/recipe.dart
//
// Módulo de Recetas:
// Entidad de dominio que reemplaza el List<Map<String,dynamic>> hardcodeado
// que antes vivía dentro de RecetasScreen y el switch de pasos de
// DetalleRecetaScreen. El contenido real (5 recetas colombianas) ahora se
// carga desde assets/data/recetas.json vía RecipeLocalDataSource — sigue
// siendo contenido estático curado, pero ya no vive embebido en un widget.
//
// La lógica de "¿qué me falta para preparar esta receta?" (antes
// verificarIngredientes() en RecetasScreen) se mueve aquí como comportamiento
// de la entidad: compara por nombre de ingrediente contra el inventario real
// (Product), igual que el criterio original (no valida cantidades, solo
// presencia — mismo comportamiento funcional que el mock que reemplaza).

import 'recipe_ingredient.dart';

class Recipe {
  final String id;
  final String name;
  final int servings;
  final List<RecipeIngredient> ingredients;
  final String imagePath;
  final List<String> steps;

  const Recipe({
    required this.id,
    required this.name,
    required this.servings,
    required this.ingredients,
    required this.imagePath,
    required this.steps,
  });

  /// Ingredientes que NO están presentes en [inventoryNames] (nombres de
  /// producto en minúsculas). Mantiene el mismo criterio que el mock
  /// original: coincidencia por nombre, sin comparar cantidades.
  List<RecipeIngredient> missingIngredients(Set<String> inventoryNames) {
    return ingredients
        .where((i) => !inventoryNames.contains(i.name.toLowerCase()))
        .toList();
  }

  bool isAvailable(Set<String> inventoryNames) =>
      missingIngredients(inventoryNames).isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Recipe && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Recipe(id: $id, name: $name)';
}
