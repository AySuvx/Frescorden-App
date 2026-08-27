// lib/presentation/utils/food_category_ui.dart
//
// PASO 2 — Categorización de Alimentos (#1):
// Mapeo de FoodCategory -> IconData. Vive en `presentation` (y no en
// `domain`) porque IconData es un detalle de Flutter/UI, no una regla
// de negocio. Las pantallas importan esta extensión en vez de repetir
// el switch-case cada vez que necesitan mostrar un ícono de categoría.

import 'package:flutter/material.dart';
import '../../domain/entities/food_category.dart';

extension FoodCategoryUi on FoodCategory {
  IconData get icon {
    switch (this) {
      case FoodCategory.lacteos:
        return Icons.icecream_outlined;
      case FoodCategory.carnesYEmbutidos:
        return Icons.kebab_dining_outlined;
      case FoodCategory.frutasYVerduras:
        return Icons.eco_outlined;
      case FoodCategory.granosYCereales:
        return Icons.grain_outlined;
      case FoodCategory.panaderia:
        return Icons.bakery_dining_outlined;
      case FoodCategory.bebidas:
        return Icons.local_drink_outlined;
      case FoodCategory.congelados:
        return Icons.ac_unit_outlined;
      case FoodCategory.condimentosYSalsas:
        return Icons.liquor_outlined;
      case FoodCategory.enlatadosYConservas:
        return Icons.inventory_2_outlined;
      case FoodCategory.otros:
        return Icons.category_outlined;
    }
  }
}
