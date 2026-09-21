// Contrato mínimo (ISP) con lo que el módulo de Productos necesita de
// Analytics. AnalyticsService expone más eventos (asistente, hogares) que
// no son responsabilidad de este módulo, así que no se listan aquí.

abstract interface class IAnalyticsService {
  /// Trazabilidad de Desperdicio vs. Consumo: quién retira un producto y
  /// qué eligió.
  Future<void> logProductResolved({required String outcome});
}
