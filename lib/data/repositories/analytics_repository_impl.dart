// Implementación de IAnalyticsRepository. Lee el historial del hogar activo
// (FirestoreProductHistoryDataSource.getAll(householdId)), lo acota al
// último mes ("Analítica Avanzada" es un reporte mensual del hogar) y
// calcula los KPIs de AnalyticsSummary sobre esa ventana. Sin historial en
// el último mes, retorna AnalyticsSummary.empty() — la UI decide cómo
// mostrar ese estado (ver AnalyticsScreen).

import '../../domain/entities/analytics_summary.dart';
import '../../domain/entities/category_waste_stats.dart';
import '../../domain/entities/food_category.dart';
import '../../domain/entities/product_history_entry.dart';
import '../../domain/entities/product_ranking_entry.dart';
import '../../domain/repositories/i_analytics_repository.dart';
import '../datasources/firestore_product_history_datasource.dart';

class AnalyticsRepositoryImpl implements IAnalyticsRepository {
  final FirestoreProductHistoryDataSource _dataSource;

  AnalyticsRepositoryImpl(this._dataSource);

  static const _windowDuration = Duration(days: 30);

  @override
  Future<AnalyticsSummary> getSummary(String householdId) async {
    final allHistory = await _dataSource.getAll(householdId);

    final cutoff = DateTime.now().subtract(_windowDuration);
    final history =
        allHistory.where((e) => e.resolvedAt.isAfter(cutoff)).toList();
    if (history.isEmpty) return AnalyticsSummary.empty();

    final consumedOnTime =
        history.where((e) => e.outcome == ProductOutcome.consumedOnTime);
    final discarded =
        history.where((e) => e.outcome == ProductOutcome.expired);

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

    final discardedBreakdown = discarded.toList()
      ..sort((a, b) => b.resolvedAt.compareTo(a.resolvedAt));

    return AnalyticsSummary(
      wasteReductionPercentage: wasteReductionPercentage,
      moneySavedCop: moneySavedCop,
      averageRotationDays: averageRotationDays,
      worstExpirationCategory: _worstExpirationCategory(categoryBreakdown),
      totalResolved: history.length,
      categoryBreakdown: categoryBreakdown,
      topConsumedProduct: _topProduct(consumedOnTime),
      topDiscardedProduct: _topProduct(discarded),
      discardedBreakdown: discardedBreakdown,
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

  /// Top Alimentos: producto con más apariciones dentro de [entries]
  /// (ya filtradas por outcome — consumidos o desperdiciados). `null` si
  /// [entries] está vacío.
  ProductRankingEntry? _topProduct(Iterable<ProductHistoryEntry> entries) {
    final counts = <String, int>{};
    for (final entry in entries) {
      final name = entry.name.trim();
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;

    final top = counts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    return ProductRankingEntry(name: top.key, count: top.value);
  }
}
