// Contrato mínimo (ISP) con lo que el módulo de Hogares necesita de
// Analytics — separado de IAnalyticsService (Productos) porque ningún
// módulo necesita el conjunto completo de eventos que expone
// AnalyticsService.

abstract interface class IHouseholdAnalyticsService {
  /// Se creó un hogar nuevo (manual o vía bootstrap de migración legacy).
  Future<void> logHouseholdCreated();

  /// Un usuario se unió a un hogar existente mediante código de invitación.
  Future<void> logHouseholdJoined();
}
