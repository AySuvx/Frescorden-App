// lib/domain/usecases/get_analytics_usecase.dart
//
// FASE 3 — primer caso de uso explícito del proyecto. Hasta ahora los
// providers llamaban directo al repositorio (ver ProductProvider,
// RecipeProvider, ShoppingProvider); este es más delgado — hoy solo
// delega — pero establece el punto de extensión: si más adelante
// "obtener analíticas" necesita orquestar más de un repositorio (ej.
// cruzar con metas de usuario), el cambio vive aquí, no en el provider.

import '../entities/analytics_summary.dart';
import '../repositories/i_analytics_repository.dart';

class GetAnalyticsUseCase {
  final IAnalyticsRepository _repository;

  const GetAnalyticsUseCase(this._repository);

  Future<AnalyticsSummary> call() => _repository.getSummary();
}
