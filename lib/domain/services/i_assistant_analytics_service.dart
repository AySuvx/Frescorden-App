// Contrato mínimo (ISP) con lo que el módulo de Asistente necesita de
// Analytics — igual criterio que IAnalyticsService (Productos) e
// IHouseholdAnalyticsService (Hogares): un evento por módulo, no un
// contrato genérico compartido.

abstract interface class IAssistantAnalyticsService {
  /// Adopción del Asistente Culinario: una consulta exitosa.
  Future<void> logAssistantQuery();
}
