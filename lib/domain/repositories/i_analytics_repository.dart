// lib/domain/repositories/i_analytics_repository.dart
//
// Contrato que define QUÉ resumen de analíticas está disponible, sin
// especificar CÓMO se calcula (hoy: agregando ProductHistoryEntry desde
// Firestore — ver AnalyticsRepositoryImpl). Regla de dependencias de
// Clean Architecture: domain ← data.

import '../entities/analytics_summary.dart';

abstract interface class IAnalyticsRepository {
  Future<AnalyticsSummary> getSummary();
}
