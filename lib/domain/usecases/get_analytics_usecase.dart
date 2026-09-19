// Punto de extensión: hoy solo delega al repositorio, pero si "obtener
// analíticas" necesita orquestar más de un repositorio (ej. cruzar con
// metas de usuario), el cambio vive aquí, no en el provider.

import '../entities/analytics_summary.dart';
import '../repositories/i_analytics_repository.dart';

class GetAnalyticsUseCase {
  final IAnalyticsRepository _repository;

  const GetAnalyticsUseCase(this._repository);

  Future<AnalyticsSummary> call(String householdId) =>
      _repository.getSummary(householdId);
}
