// lib/data/repositories/analytics_repository_impl.dart
//
// Implementación de IAnalyticsRepository. Lee todo el historial
// (FirestoreProductHistoryDataSource.getAll()) y calcula los 4 KPIs de
// AnalyticsSummary. Sin historial (usuario nuevo, o nadie ha eliminado
// productos todavía), retorna AnalyticsSummary.empty() — la UI decide cómo
// mostrar ese estado (ver AnalyticsScreen).

import '../../domain/entities/analytics_summary.dart';
import '../../domain/entities/category_waste_stats.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/product_history_entry.dart';
import '../../domain/repositories/i_analytics_repository.dart';
import '../datasources/firestore_product_history_datasource.dart';

class AnalyticsRepositoryImpl implements IAnalyticsRepository {
  final FirestoreProductHistoryDataSource _dataSource;

  AnalyticsRepositoryImpl(this._dataSource);

  @override
  Future<AnalyticsSummary> getSummary() async {
    final history = await _dataSource.getAll();
    if (history.isEmpty) return AnalyticsSummary.empty();

    final consumedOnTime =
        history.where((e) => e.outcome == ProductOutcome.consumedOnTime);

    final wasteReductionPercentage =
        consumedOnTime.length / history.length * 100;

    final moneySavedCop = consumedOnTime.fold<int>(
      0,
      (sum, e) => sum + (e.estimatedPrice ?? 0),
    );

    final averageRotationDays =
        history.fold<int>(0, (sum, e) => sum + e.daysInStorage) /
            history.length;

    final categoryBreakdown = _categoryBreakdown(history);

    return AnalyticsSummary(
      wasteReductionPercentage: wasteReductionPercentage,
      moneySavedCop: moneySavedCop,
      averageRotationDays: averageRotationDays,
      worstExpirationCategory: _worstExpirationCategory(categoryBreakdown),
      totalResolved: history.length,
      categoryBreakdown: categoryBreakdown,
    );
  }

  /// Agrupa el historial por categoría, contando consumidos a tiempo vs.
  /// vencidos. Base tanto de `worstExpirationCategory` como de los gráficos
  /// (WasteVsConsumedBarChart, WasteCategoryPieChart). Ordenado por total
  /// descendente para que los gráficos muestren primero lo más relevante.
  List<CategoryWasteStats> _categoryBreakdown(
    List<ProductHistoryEntry> history,
  ) {
    final consumedByCategory = <FoodCategory, int>{};
    final expiredByCategory = <FoodCategory, int>{};

    for (final entry in history) {
      if (entry.outcome == ProductOutcome.expired) {
        expiredByCategory[entry.category] =
            (expiredByCategory[entry.category] ?? 0) + 1;
      } else {
        consumedByCategory[entry.category] =
            (consumedByCategory[entry.category] ?? 0) + 1;
      }
    }

    final categories = {...consumedByCategory.keys, ...expiredByCategory.keys};
    final breakdown = categories
        .map(
          (category) => CategoryWasteStats(
            category: category,
            consumedOnTime: consumedByCategory[category] ?? 0,
            expired: expiredByCategory[category] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return breakdown;
  }

  /// Categoría con mayor tasa de vencimiento (vencidos / total de esa
  /// categoría). `null` si ninguna categoría tuvo al menos un producto
  /// vencido.
  FoodCategory? _worstExpirationCategory(
    List<CategoryWasteStats> categoryBreakdown,
  ) {
    FoodCategory? worst;
    double worstRate = 0;
    for (final stats in categoryBreakdown) {
      if (stats.expired == 0) continue;
      final rate = stats.expired / stats.total;
      if (rate > worstRate) {
        worstRate = rate;
        worst = stats.category;
      }
    }
    return worst;
  }
}
