// Mismo criterio que RecipeLocalDataSource: el catálogo de alimentos
// preestablecidos es contenido curado y estático (igual que las recetas),
// no datos de usuario, así que vive en un asset JSON local en vez de una
// colección Firestore.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../domain/entities/preset_food.dart';
import '../models/preset_food_model.dart';

class PresetFoodLocalDataSource {
  static const _assetPath = 'assets/data/preset_foods.json';

  Future<List<PresetFood>> getAll() async {
    final raw = await rootBundle.loadString(_assetPath);
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((json) => PresetFoodModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
