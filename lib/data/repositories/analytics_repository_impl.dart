// lib/data/repositories/analytics_repository_impl.dart
//
// Implementación de IAnalyticsRepository. Lee todo el historial
// (FirestoreProductHistoryDataSource.getAll()) y calcula los 4 KPIs de
// AnalyticsSummary. Sin historial (usuario nuevo, o nadie ha eliminado
// productos todavía), retorna AnalyticsSummary.empty() — la UI decide cómo
// mostrar ese estado (ver AnalyticsScreen).

import '../../domain/entities/analytics_summary.dart';
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

    return AnalyticsSummary(
      wasteReductionPercentage: wasteReductionPercentage,
      moneySavedCop: moneySavedCop,
      averageRotationDays: averageRotationDays,
      worstExpirationCategory: _worstExpirationCategory(history),
      totalResolved: history.length,
    );
  }

  /// Categoría con mayor tasa de vencimiento (vencidos / total de esa
  /// categoría). Ignora categorías sin historial. `null` si ninguna
  /// categoría tuvo al menos un producto vencido.
  FoodCategory? _worstExpirationCategory(List<ProductHistoryEntry> history) {
    final totalByCategory = <FoodCategory, int>{};
    final expiredByCategory = <FoodCategory, int>{};

    for (final entry in history) {
      totalByCategory[entry.category] =
          (totalByCategory[entry.category] ?? 0) + 1;
      if (entry.outcome == ProductOutcome.expired) {
        expiredByCategory[entry.category] =
            (expiredByCategory[entry.category] ?? 0) + 1;
      }
    }

    FoodCategory? worst;
    double worstRate = 0;
    for (final category in expiredByCategory.keys) {
      final rate = expiredByCategory[category]! / totalByCategory[category]!;
      if (rate > worstRate) {
        worstRate = rate;
        worst = category;
      }
    }
    return worst;
  }
}
