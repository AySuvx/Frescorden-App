// lib/data/datasources/recipe_local_datasource.dart
//
// Única clase que sabe DÓNDE viven las recetas: un asset JSON local
// (assets/data/recetas.json). Las recetas son contenido curado y estático
// (igual que las imágenes ya empaquetadas en assets/), no datos de usuario,
// por lo que no se justifica una colección Firestore ni una lectura de red
// para servirlas.
//
// Si en el futuro se quiere gestionar recetas desde un backend (agregar
// nuevas sin publicar una versión de la app), basta con crear un
// RecipeRemoteDataSource y otro RecipeRepositoryImpl que lo use — el resto
// de la app no cambia porque depende de IRecipeRepository, no de esta clase.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/recipe_model.dart';
import '../../domain/entities/recipe.dart';

class RecipeLocalDataSource {
  static const _assetPath = 'assets/data/recetas.json';

  Future<List<Recipe>> getAll() async {
    final raw = await rootBundle.loadString(_assetPath);
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((json) => RecipeModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
