// lib/domain/entities/recipe_ingredient.dart
//
// Módulo de Recetas:
// Value object que representa un ingrediente requerido por una [Recipe].
// Vive en domain porque es parte del vocabulario del negocio (qué
// necesita una receta), sin depender de Flutter ni de la fuente de datos.

class RecipeIngredient {
  final String name;
  final num quantity;
  final String unit;

  const RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeIngredient &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          quantity == other.quantity &&
          unit == other.unit;

  @override
  int get hashCode => Object.hash(name, quantity, unit);

  @override
  String toString() => 'RecipeIngredient($quantity $unit $name)';
}
