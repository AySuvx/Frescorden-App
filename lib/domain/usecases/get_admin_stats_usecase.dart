// Mismo rol que GetAnalyticsUseCase: punto de extensión si "obtener
// métricas globales" necesita orquestar más de un repositorio más adelante.
// Hoy solo delega.

import '../entities/admin_stats.dart';
import '../repositories/i_admin_repository.dart';

class GetAdminStatsUseCase {
  final IAdminRepository _repository;

  const GetAdminStatsUseCase(this._repository);

  Future<AdminStats> call() => _repository.getGlobalStats();
}
