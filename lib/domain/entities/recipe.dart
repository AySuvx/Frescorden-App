// Entidad de dominio para una receta. El contenido real (recetas
// colombianas) se carga desde assets/data/recetas.json vía
// RecipeLocalDataSource — contenido estático curado, no embebido en un widget.
//
// La lógica de "¿qué me falta para preparar esta receta?" vive aquí como
// comportamiento de la entidad: compara por nombre de ingrediente contra
// el inventario real (Product), sin validar cantidades, solo presencia.

import 'recipe_ingredient.dart';

class Recipe {
  final String id;
  final String name;
  final int servings;
  final List<RecipeIngredient> ingredients;
  final String imagePath;
  final List<String> steps;

  /// Tiempo aproximado de preparación, en minutos. Antes vivía como texto
  /// suelto dentro del último paso ("... Tiempo total: 10 minutos") — se
  /// separa a un campo estructurado para poder mostrarlo en un chip de
  /// metadatos sin parsear prosa.
  final int prepTimeMinutes;

  /// `true` cuando esta receta fue generada dinámicamente por Gemini (no
  /// viene del catálogo curado) — permite a la UI distinguirla si hace
  /// falta (p. ej. no ofrecerla de nuevo en un "ver más" del catálogo).
  final bool isAiGenerated;

  const Recipe({
    required this.id,
    required this.name,
    required this.servings,
    required this.ingredients,
    required this.imagePath,
    required this.steps,
    this.prepTimeMinutes = 20,
    this.isAiGenerated = false,
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

  /// Porcentaje de ingredientes que el usuario YA tiene (0.0 a 1.0) — base
  /// de la coincidencia flexible: en vez de ocultar
  /// una receta por faltarle algo, se usa esto para ordenar el catálogo de
  /// mayor a menor disponibilidad. Una receta sin ingredientes declarados
  /// (no debería pasar, pero por seguridad) cuenta como 100% disponible en
  /// vez de dividir por cero.
  double matchPercentage(Set<String> inventoryNames) {
    if (ingredients.isEmpty) return 1;
    final have = ingredients.length - missingIngredients(inventoryNames).length;
    return have / ingredients.length;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Recipe && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Recipe(id: $id, name: $name)';
}
