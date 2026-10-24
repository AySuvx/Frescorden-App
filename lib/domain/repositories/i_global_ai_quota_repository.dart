// Contrato para la cuota diaria de Gemini COMPARTIDA entre TODOS los
// dispositivos del piloto (a diferencia de IQuotaService, que es por
// dispositivo vía SharedPreferences). El plan Spark de Firebase limita el
// proyecto completo a 20 solicitudes/día para el modelo — un límite por
// dispositivo no evita que varios testers juntos agoten esa cuota
// compartida. Mismo shape que IQuotaService a propósito: los proveedores
// que ya saben consumir ese contrato (AssistantProvider, RecipeProvider)
// reutilizan la misma lógica, solo que contra esta segunda fuente.

abstract interface class IGlobalAiQuotaRepository {
  /// Consultas que quedan disponibles hoy para el proyecto.
  Future<int> getRemaining();

  /// Registra una consulta ya respondida con éxito (suma al contador
  /// compartido) y devuelve las consultas restantes.
  Future<int> recordSuccessfulQuery();

  /// Medianoche UTC del día siguiente — cuándo se reinicia el contador
  /// compartido (UTC y no hora local: el documento de Firestore se
  /// identifica por fecha UTC para que todos los dispositivos, sin
  /// importar su zona horaria, lean y escriban el mismo contador del día).
  DateTime nextResetAt();
}
