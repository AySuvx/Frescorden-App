// Contrato para la cuota diaria de consultas a Gemini, compartida entre
// Recetas (fallback de IA) y el Asistente Culinario — mismo contrato para
// ambos módulos porque ambos consumen exactamente el mismo comportamiento,
// a diferencia de Analytics (eventos distintos por módulo, ver ISP en
// IAnalyticsService/IHouseholdAnalyticsService).

abstract interface class IQuotaService {
  /// Consultas que quedan disponibles hoy.
  Future<int> getRemaining();

  /// Registra una consulta ya respondida con éxito y devuelve las
  /// consultas restantes.
  Future<int> recordSuccessfulQuery();

  /// Medianoche del día siguiente (hora local del dispositivo) — cuándo
  /// se reinicia la cuota.
  DateTime nextResetAt();
}
