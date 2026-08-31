// lib/presentation/utils/food_category_ui.dart
//
// Categorización de Alimentos (#1):
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

  /// Color estable por categoría, usado en los gráficos de
  /// analíticas (WasteVsConsumedBarChart, WasteCategoryPieChart) y su
  /// leyenda. Mismo criterio que `icon`: es un detalle de presentación,
  /// no una regla de negocio, por eso vive aquí y no en el dominio.
  Color get chartColor {
    switch (this) {
      case FoodCategory.lacteos:
        return const Color(0xFF64B5F6); // azul
      case FoodCategory.carnesYEmbutidos:
        return const Color(0xFFE57373); // rojo
      case FoodCategory.frutasYVerduras:
        return const Color(0xFF81C784); // verde
      case FoodCategory.granosYCereales:
        return const Color(0xFFD4A76A); // marrón claro
      case FoodCategory.panaderia:
        return const Color(0xFFFFB74D); // naranja
      case FoodCategory.bebidas:
        return const Color(0xFF4DD0E1); // cian
      case FoodCategory.congelados:
        return const Color(0xFF9575CD); // morado
      case FoodCategory.condimentosYSalsas:
        return const Color(0xFFFFD54F); // amarillo
      case FoodCategory.enlatadosYConservas:
        return const Color(0xFF90A4AE); // gris azulado
      case FoodCategory.otros:
        return const Color(0xFFA1887F); // marrón neutro
    }
  }
}
