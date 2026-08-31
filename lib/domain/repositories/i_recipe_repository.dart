// lib/domain/repositories/i_recipe_repository.dart
//
// Contrato (interfaz) que define QUÉ recetas están disponibles, sin
// especificar CÓMO se obtienen. El dominio depende de esta abstracción;
// la implementación real (assets locales, Firestore en el futuro, etc.)
// vive en lib/data/.
//
// Regla de dependencias de Clean Architecture:
//   domain ← data (data implementa domain, no al revés)

import '../entities/recipe.dart';

abstract interface class IRecipeRepository {
  /// Carga el catálogo completo de recetas disponibles en la app.
  Future<List<Recipe>> getRecipes();
}
