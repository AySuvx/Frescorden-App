// lib/presentation/providers/recipe_provider.dart
//
// Proveedor de estado para recetas. Implementa ChangeNotifier (mismo patrón
// que ProductProvider). Reemplaza la lista hardcodeada y el método
// verificarIngredientes() que antes vivían dentro de RecetasScreen.
//
// La pantalla ya NO conoce el formato del JSON ni compara ingredientes
// directamente: solo consume `recipes`, `missingIngredientsFor()` e
// `isAvailable()`.

import 'package:flutter/foundation.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_ingredient.dart';
import '../../domain/repositories/i_recipe_repository.dart';

class RecipeProvider extends ChangeNotifier {
  final IRecipeRepository _repository;

  RecipeProvider(this._repository);

  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String? _error;

  List<Recipe> get recipes => List.unmodifiable(_recipes);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRecipes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recipes = await _repository.getRecipes();
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('RecipeProvider.loadRecipes error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Nombres de producto en minúsculas, listos para comparar contra
  /// ingredientes de receta (mismo criterio que el mock original).
  Set<String> _inventoryNames(List<Product> inventory) =>
      inventory.map((p) => p.name.toLowerCase()).toSet();

  List<RecipeIngredient> missingIngredientsFor(
    Recipe recipe,
    List<Product> inventory,
  ) {
    return recipe.missingIngredients(_inventoryNames(inventory));
  }

  bool isAvailable(Recipe recipe, List<Product> inventory) {
    return recipe.isAvailable(_inventoryNames(inventory));
  }

  /// Recetas para las que el inventario actual tiene todos los ingredientes.
  List<Recipe> availableRecipes(List<Product> inventory) {
    final names = _inventoryNames(inventory);
    return _recipes.where((r) => r.isAvailable(names)).toList();
  }
}
