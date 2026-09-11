// lib/domain/entities/product_history_entry.dart
//
// Historial de Productos:
// Registro de un producto ya resuelto (eliminado del inventario), con el
// dato que antes se perdía por completo: ¿se consumió a tiempo o venció?
// Esta es la fuente de datos cruda sobre la que AnalyticsRepositoryImpl
// calcula el AnalyticsSummary — sin historial no hay analíticas reales.
//
// Se crea en ProductProvider.deleteProduct() (ver ese archivo) con el
// `outcome` que la pantalla recibe del diálogo de confirmación
// "Consumido" / "Desperdiciado" (Fase 4.5, Módulo 3) — explícito, ya no
// inferido comparando la fecha de eliminación contra `expirationDate`.

import 'food_category.dart';

enum ProductOutcome { consumedOnTime, expired }

class ProductHistoryEntry {
  final String productId;
  final String name;
  final FoodCategory category;
  final DateTime entryDate;
  final DateTime? expirationDate;
  final DateTime resolvedAt;
  final ProductOutcome outcome;

  /// Precio estimado en COP (Opción A: resuelto por
  /// ProductHistoryRepositoryImpl buscando coincidencia de nombre en el
  /// catálogo de canastas.json). `null` si no se encontró coincidencia —
  /// no aporta a `AnalyticsSummary.moneySavedCop`, pero no rompe el cálculo.
  final int? estimatedPrice;

  const ProductHistoryEntry({
    required this.productId,
    required this.name,
    required this.category,
    required this.entryDate,
    this.expirationDate,
    required this.resolvedAt,
    required this.outcome,
    this.estimatedPrice,
  });

  /// Días que el producto permaneció en el inventario antes de resolverse.
  /// Base de `AnalyticsSummary.averageRotationDays`.
  int get daysInStorage => resolvedAt.difference(entryDate).inDays;

  ProductHistoryEntry copyWith({int? estimatedPrice}) {
    return ProductHistoryEntry(
      productId: productId,
      name: name,
      category: category,
      entryDate: entryDate,
      expirationDate: expirationDate,
      resolvedAt: resolvedAt,
      outcome: outcome,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
    );
  }
}
