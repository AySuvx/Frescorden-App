// lib/domain/repositories/i_recipe_repository.dart
//
// Contrato (interfaz) que define QUÉ recetas están disponibles, sin
// especificar CÓMO se obtienen. El dominio depende de esta abstracción;
// la implementación real (assets locales, Firestore en el futuro, etc.)
// vive en lib/data/.
//
// Regla de dependencias de Clean Architecture:
//   domain ← data (data implementa domain, no al revés)

import '../entities/product.dart';
import '../entities/recipe.dart';

abstract interface class IRecipeRepository {
  /// Carga el catálogo completo de recetas disponibles en la app.
  Future<List<Recipe>> getRecipes();

  /// Genera una receta colombiana nueva con IA (Gemini), priorizando los
  /// ingredientes de [inventory] — fallback dinámico (Fase 5, Módulo 3.6)
  /// para cuando el catálogo curado no tiene una buena coincidencia. No se
  /// persiste en el catálogo local: es un resultado efímero para esa
  /// consulta puntual.
  Future<Recipe> generateAiRecipe(List<Product> inventory);
}
