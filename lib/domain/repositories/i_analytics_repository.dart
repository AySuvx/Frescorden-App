// Contrato que define QUÉ resumen de analíticas está disponible, sin
// especificar CÓMO se calcula (hoy: agregando ProductHistoryEntry del hogar
// activo desde Firestore — ver AnalyticsRepositoryImpl). Regla de
// dependencias de Clean Architecture: domain ← data.

import '../entities/analytics_summary.dart';

abstract interface class IAnalyticsRepository {
  /// Resumen de analíticas del hogar [householdId], acotado al último mes.
  Future<AnalyticsSummary> getSummary(String householdId);
}
