// lib/domain/entities/product_ranking_entry.dart
//
// Analítica Avanzada (Fase 4.5, Módulo 3) — "Top Alimentos":
// Producto y cuántas veces apareció con un ProductOutcome dado (consumido o
// desperdiciado) dentro de la ventana analizada por AnalyticsRepositoryImpl.

class ProductRankingEntry {
  final String name;
  final int count;

  const ProductRankingEntry({required this.name, required this.count});
}
