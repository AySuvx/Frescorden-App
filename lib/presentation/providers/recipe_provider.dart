// lib/presentation/providers/recipe_provider.dart
//
// Proveedor de estado para recetas. Implementa ChangeNotifier (mismo patrón
// que ProductProvider). Reemplaza la lista hardcodeada y el método
// verificarIngredientes() que antes vivían dentro de RecetasScreen.
//
// La pantalla ya NO conoce el formato del JSON ni compara ingredientes
// directamente: solo consume `recipes`, `missingIngredientsFor()` e
// `isAvailable()`.
//
// Fase 5, Módulo 3.6 — coincidencia flexible: ya no se OCULTAN recetas por
// insumos faltantes (ver `sortedByMatch`, que devuelve TODO el catálogo
// ordenado de mayor a menor disponibilidad) y se agrega el fallback de IA
// (`generateAiRecipe`), sujeto a la misma cuota diaria que el asistente
// conversacional — es el mismo costo de Gemini, así que comparte el
// contador (ver QuotaService).

import 'package:flutter/foundation.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_ingredient.dart';
import '../../domain/repositories/i_recipe_repository.dart';
import '../utils/quota_service.dart';

class RecipeProvider extends ChangeNotifier {
  final IRecipeRepository _repository;

  RecipeProvider(this._repository);

  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String? _error;

  bool _isGeneratingAiRecipe = false;
  String? _aiError;

  List<Recipe> get recipes => List.unmodifiable(_recipes);
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isGeneratingAiRecipe => _isGeneratingAiRecipe;
  String? get aiError => _aiError;

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

  /// Catálogo completo ordenado de mayor a menor disponibilidad — ninguna
  /// receta se oculta por faltarle ingredientes (a diferencia del filtro
  /// "solo disponibles" que existía antes). En empate, se mantiene el
  /// orden original del catálogo (`sort` es estable en Dart).
  List<Recipe> sortedByMatch(List<Product> inventory) {
    final names = _inventoryNames(inventory);
    final sorted = [..._recipes];
    sorted.sort(
      (a, b) => b.matchPercentage(names).compareTo(a.matchPercentage(names)),
    );
    return sorted;
  }

  /// Mejor coincidencia del catálogo actual (0.0 a 1.0) — dispara el
  /// fallback de IA en la pantalla cuando es baja. `1.0` si no hay
  /// recetas cargadas todavía, para no ofrecer el fallback de IA antes de
  /// tiempo mientras el catálogo sigue cargando.
  double bestMatchPercentage(List<Product> inventory) {
    if (_recipes.isEmpty) return 1;
    final names = _inventoryNames(inventory);
    return _recipes
        .map((r) => r.matchPercentage(names))
        .reduce((a, b) => a > b ? a : b);
  }

  /// Recetas para las que el inventario actual tiene todos los
  /// ingredientes — se conserva para quien todavía quiera filtrar así
  /// (no se usa en el nuevo diseño de RecetasScreen, que muestra todo).
  List<Recipe> availableRecipes(List<Product> inventory) {
    final names = _inventoryNames(inventory);
    return _recipes.where((r) => r.isAvailable(names)).toList();
  }

  /// Genera una receta colombiana con IA priorizando [inventory] —
  /// fallback dinámico cuando el catálogo curado no encaja bien. Sujeta a
  /// la cuota diaria compartida con el asistente conversacional (mismo
  /// costo real de Gemini); solo se descuenta tras una respuesta exitosa.
  /// Devuelve `null` si la cuota ya se agotó o si Gemini falla — el error
  /// queda en `aiError` para que la UI lo muestre.
  Future<Recipe?> generateAiRecipe(List<Product> inventory) async {
    if (_isGeneratingAiRecipe) return null;
    final remaining = await QuotaService.instance.getRemaining();
    if (remaining <= 0) {
      _aiError = 'Ya usaste tus consultas de IA de hoy. Vuelve mañana.';
      notifyListeners();
      return null;
    }

    _isGeneratingAiRecipe = true;
    _aiError = null;
    notifyListeners();

    try {
      final recipe = await _repository.generateAiRecipe(inventory);
      await QuotaService.instance.recordSuccessfulQuery();
      return recipe;
    } catch (e) {
      _aiError = 'No se pudo crear la receta. Intenta de nuevo.';
      debugPrint('RecipeProvider.generateAiRecipe error: $e');
      return null;
    } finally {
      _isGeneratingAiRecipe = false;
      notifyListeners();
    }
  }
}
