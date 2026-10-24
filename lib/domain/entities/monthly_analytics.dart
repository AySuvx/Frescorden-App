// Un punto del historial mes a mes (ver AnalyticsSummary.monthlyHistory) —
// base del gráfico de tendencia de ahorro. A diferencia del resto de
// AnalyticsSummary (acotado a los últimos 30 días), esto cubre varios
// meses hacia atrás para poder dibujar una línea de progreso.

class MonthlyAnalytics {
  /// Primer día del mes que representa este punto (hora local, sin
  /// componente de tiempo relevante) — solo se usa month/year para
  /// etiquetar el eje X del gráfico.
  final DateTime month;

  final int moneySavedCop;
  final double wasteReductionPercentage;
  final int totalResolved;

  const MonthlyAnalytics({
    required this.month,
    required this.moneySavedCop,
    required this.wasteReductionPercentage,
    required this.totalResolved,
  });
}
