// lib/data/datasources/shopping_local_datasource.dart
//
// Única clase que sabe DÓNDE vive el catálogo de canastas básicas por nivel
// de presupuesto: un asset JSON local (assets/data/canastas.json), clave
// por BudgetTier.name. Mismo criterio que RecipeLocalDataSource: contenido
// curado y estático, no datos de usuario, así que no se justifica Firestore.

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/shopping_item_model.dart';
import '../../domain/entities/budget_tier.dart';
import '../../domain/entities/shopping_item.dart';

class ShoppingLocalDataSource {
  static const _assetPath = 'assets/data/canastas.json';

  Future<List<ShoppingItem>> getBasket(BudgetTier tier) async {
    final raw = await rootBundle.loadString(_assetPath);
    final Map<String, dynamic> decoded =
        jsonDecode(raw) as Map<String, dynamic>;
    final List<dynamic> items = decoded[tier.name] as List<dynamic>? ?? [];
    return items
        .map((json) => ShoppingItemModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
