// Producto y cuántas veces apareció con un ProductOutcome dado (consumido o
// desperdiciado) dentro de la ventana analizada por AnalyticsRepositoryImpl.

class ProductRankingEntry {
  final String name;
  final int count;

  const ProductRankingEntry({required this.name, required this.count});
}
