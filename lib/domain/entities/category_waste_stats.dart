// lib/domain/entities/category_waste_stats.dart
//
// Gráficos de Analíticas (fl_chart):
// Desglose por categoría de cuántos productos se consumieron a tiempo vs.
// cuántos vencieron. Es la base de datos de ambos gráficos:
//  - WasteVsConsumedBarChart: consumedOnTime vs expired por categoría.
//  - WasteCategoryPieChart: proporción de expired por categoría sobre el
//    total de productos vencidos.
//
// Vive en domain (no en presentation) porque es un agregado del historial
// de negocio, no un detalle de cómo se dibuja — los widgets de fl_chart
// solo lo consumen y lo traducen a BarChartGroupData/PieChartSectionData.

import 'food_category.dart';

class CategoryWasteStats {
  final FoodCategory category;
  final int consumedOnTime;
  final int expired;

  const CategoryWasteStats({
    required this.category,
    required this.consumedOnTime,
    required this.expired,
  });

  int get total => consumedOnTime + expired;
}
