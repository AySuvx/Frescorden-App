// Predice qué productos del inventario actual "se deben estar acabando",
// comparando cuánto tiempo llevan registrados contra cada cuánto el hogar
// suele volver a comprar ese mismo producto (promedio de los intervalos
// entre entryDate consecutivos del historial). Sin IA: pura aritmética
// sobre datos que la app ya guarda (ProductHistoryEntry), así que no
// compite por cuota de Gemini ni depende de que el servicio esté arriba.
//
// Coincidencia por NOMBRE (mismo criterio que ShoppingProvider/RecipeProvider
// al cruzar contra el inventario): no hay un ID estable entre "el mismo
// producto" a través de reposiciones distintas.

import '../entities/product.dart';
import '../entities/product_history_entry.dart';
import '../entities/restock_prediction.dart';

class PredictRestockUseCase {
  const PredictRestockUseCase();

  /// Mínimo de entradas históricas de un mismo producto para calcular un
  /// ciclo promedio confiable — con solo 1 no hay "intervalo" que promediar.
  static const _minHistoryEntries = 2;

  /// Qué tan avanzado el ciclo habitual debe estar el producto actual para
  /// mostrarlo como predicción — 0.75 = ya pasó el 75% del tiempo que
  /// usualmente dura antes de reponerse.
  static const _urgencyThreshold = 0.75;

  List<RestockPrediction> call({
    required List<ProductHistoryEntry> history,
    required List<Product> inventory,
  }) {
    final cyclesByName = _averageCycleByName(history);
    final now = DateTime.now();

    final predictions = <RestockPrediction>[];
    for (final product in inventory) {
      final key = product.name.trim().toLowerCase();
      final cycle = cyclesByName[key];
      if (cycle == null) continue;

      final daysSinceEntry = now.difference(product.entryDate).inDays;
      final prediction = RestockPrediction(
        productName: product.name,
        category: product.category,
        unit: product.unit,
        averageCycleDays: cycle,
        daysSinceEntry: daysSinceEntry,
      );
      if (prediction.urgency >= _urgencyThreshold) predictions.add(prediction);
    }

    predictions.sort((a, b) => b.urgency.compareTo(a.urgency));
    return predictions;
  }

  /// Para cada nombre de producto (en minúsculas), ordena sus entradas
  /// históricas por `entryDate` y promedia los intervalos entre
  /// consecutivas — ese promedio es "cada cuánto el hogar suele comprarlo".
  Map<String, int> _averageCycleByName(List<ProductHistoryEntry> history) {
    final entriesByName = <String, List<DateTime>>{};
    for (final entry in history) {
      final key = entry.name.trim().toLowerCase();
      if (key.isEmpty) continue;
      (entriesByName[key] ??= []).add(entry.entryDate);
    }

    final cycles = <String, int>{};
    for (final MapEntry(key: name, value: dates) in entriesByName.entries) {
      if (dates.length < _minHistoryEntries) continue;
      dates.sort();

      var totalGapDays = 0;
      for (var i = 1; i < dates.length; i++) {
        totalGapDays += dates[i].difference(dates[i - 1]).inDays;
      }
      final averageCycle = totalGapDays ~/ (dates.length - 1);
      if (averageCycle > 0) cycles[name] = averageCycle;
    }
    return cycles;
  }
}
