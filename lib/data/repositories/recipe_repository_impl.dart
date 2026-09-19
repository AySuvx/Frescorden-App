// Implementación concreta de IRecipeRepository. El catálogo curado sigue
// viniendo del datasource local; el fallback de IA reutiliza
// GeminiAssistantDataSource — la misma clase que ya habla con Gemini para
// el asistente conversacional, con una instancia propia (ver su
// constructor: un modelo aparte, sin conversación) para no acoplar el
// módulo de recetas al estado de la conversación del asistente.

import '../../domain/entities/product.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/repositories/i_recipe_repository.dart';
import '../datasources/gemini_assistant_data_source.dart';
import '../datasources/recipe_local_datasource.dart';
import '../models/recipe_model.dart';

class RecipeRepositoryImpl implements IRecipeRepository {
  final RecipeLocalDataSource _dataSource;
  final GeminiAssistantDataSource _aiDataSource;

  RecipeRepositoryImpl(this._dataSource, this._aiDataSource);

  @override
  Future<List<Recipe>> getRecipes() {
    return _dataSource.getAll();
  }

  @override
  Future<Recipe> generateAiRecipe(List<Product> inventory) async {
    final json = await _aiDataSource.generateColombianRecipe(inventory);
    final withIdentity = {
      ...json,
      'id': 'ia_${DateTime.now().millisecondsSinceEpoch}',
      // Sin fotografía propia por receta generada — se usa una imagen
      // genérica ya empaquetada en assets/ (ver nota en recetas.json).
      'imagen': 'assets/verduras.png',
      'ia_generada': true,
    };
    return RecipeModel.fromJson(withIdentity);
  }
}
