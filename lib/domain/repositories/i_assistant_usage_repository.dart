// lib/domain/repositories/i_assistant_usage_repository.dart
//
// Contrato para registrar consultas exitosas al asistente culinario.
// QuotaService (SharedPreferences local) sigue siendo la única fuente de
// verdad para el límite diario por dispositivo — este repositorio NO
// controla cuota, solo deja un rastro server-side de que el hogar usó el
// asistente, para que el Panel Administrativo Global pueda medir adopción
// real de la función (ver AdminStats). Regla de dependencias de Clean
// Architecture: domain ← data.

abstract interface class IAssistantUsageRepository {
  /// Registra una consulta ya respondida con éxito por el hogar
  /// [householdId]. Best-effort: quien la llama (AssistantProvider) no debe
  /// dejar que un fallo aquí afecte la respuesta ya entregada al usuario.
  Future<void> logQuery({required String householdId});
}
