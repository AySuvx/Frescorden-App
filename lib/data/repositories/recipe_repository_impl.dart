// lib/data/repositories/recipe_repository_impl.dart
//
// Implementación concreta de IRecipeRepository usando el datasource local.
// Si el origen del catálogo cambia (ej. remoto), solo esta clase cambia;
// RecipeProvider y las pantallas no se enteran.

import '../../domain/entities/recipe.dart';
import '../../domain/repositories/i_recipe_repository.dart';
import '../datasources/recipe_local_datasource.dart';

class RecipeRepositoryImpl implements IRecipeRepository {
  final RecipeLocalDataSource _dataSource;

  RecipeRepositoryImpl(this._dataSource);

  @override
  Future<List<Recipe>> getRecipes() {
    return _dataSource.getAll();
  }
}
