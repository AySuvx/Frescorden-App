// Resumen agregado de KPIs, calculado por AnalyticsRepositoryImpl a partir
// del historial de productos resueltos del hogar activo (ProductHistoryEntry,
// ver getSummary). Todo el resumen queda acotado al último mes (últimos 30
// días) — "Analítica Avanzada" es, en esencia, un
// reporte mensual del hogar. Ver ese archivo para el detalle de cómo se
// calcula cada campo.

import 'category_waste_stats.dart';
import 'food_category.dart';
import 'monthly_analytics.dart';
import 'product_history_entry.dart';
import 'product_ranking_entry.dart';

class AnalyticsSummary {
  /// % de productos resueltos, en el último mes, que se consumieron
  /// (aprovechamiento) en vez de desperdiciarse (0-100).
  final double wasteReductionPercentage;

  /// Suma estimada en COP de lo "salvado" al consumir a tiempo en vez de
  /// desperdiciar (Opción A: precio estimado vía catálogo de canastas).
  final int moneySavedCop;

  /// Promedio de días en inventario antes de resolverse (consumido o
  /// vencido), sobre todo el historial.
  final double averageRotationDays;

  /// Categoría con mayor tasa de vencimiento (vencidos / total de esa
  /// categoría). `null` si no hay historial suficiente para calcularla.
  final FoodCategory? worstExpirationCategory;

  /// Total de entradas de historial consideradas. Permite a la UI mostrar
  /// un estado "sin datos aún" en vez de un 0% engañoso cuando el usuario
  /// todavía no tiene historial.
  final int totalResolved;

  /// Desglose consumido-a-tiempo vs. vencido por categoría — base de los
  /// gráficos de barras y de dona. Solo incluye categorías con al menos
  /// una entrada de historial; vacío si `!hasData`.
  final List<CategoryWasteStats> categoryBreakdown;

  /// Top Alimentos: producto que más veces se marcó como consumido en el
  /// último mes. `null` si ninguno se consumió en la ventana.
  final ProductRankingEntry? topConsumedProduct;

  /// Top Alimentos: producto que más veces se marcó como desperdiciado en
  /// el último mes. `null` si ninguno se desperdició en la ventana.
  final ProductRankingEntry? topDiscardedProduct;

  /// Desglose Histórico: entradas del último mes marcadas como
  /// desperdiciadas, de la más reciente a la más antigua.
  final List<ProductHistoryEntry> discardedBreakdown;

  /// Suma de `moneySavedCop` desde SIEMPRE (todo el historial, no solo el
  /// último mes) — "cuánto llevas ahorrado usando la app", la cifra que
  /// más valor transmite porque crece con el tiempo en vez de reiniciarse
  /// cada mes.
  final int totalMoneySavedAllTimeCop;

  /// Últimos meses (más reciente al final), uno por cada mes con al menos
  /// una entrada de historial — hasta 6. Base del gráfico de tendencia
  /// ("¿estoy mejorando o empeorando?"), algo que un solo corte de 30 días
  /// no puede responder.
  final List<MonthlyAnalytics> monthlyHistory;

  const AnalyticsSummary({
    required this.wasteReductionPercentage,
    required this.moneySavedCop,
    required this.averageRotationDays,
    required this.worstExpirationCategory,
    required this.totalResolved,
    required this.categoryBreakdown,
    required this.topConsumedProduct,
    required this.topDiscardedProduct,
    required this.discardedBreakdown,
    this.totalMoneySavedAllTimeCop = 0,
    this.monthlyHistory = const [],
  });

  factory AnalyticsSummary.empty() => const AnalyticsSummary(
        wasteReductionPercentage: 0,
        moneySavedCop: 0,
        averageRotationDays: 0,
        worstExpirationCategory: null,
        totalResolved: 0,
        categoryBreakdown: [],
        topConsumedProduct: null,
        topDiscardedProduct: null,
        discardedBreakdown: [],
      );

  /// `true` cuando hay al menos una categoría con algún producto vencido —
  /// condición mínima para que el gráfico de dona tenga algo que mostrar.
  bool get hasWasteData => categoryBreakdown.any((c) => c.expired > 0);

  bool get hasData => totalResolved > 0;
}
