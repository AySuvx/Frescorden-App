import '../entities/activity_log_entry.dart';

abstract interface class IActivityLogRepository {
  /// Registra una acción sobre un producto en el log de auditoría del
  /// hogar. El usuario que la realiza se resuelve internamente en la capa
  /// de datos (FirebaseAuth.instance.currentUser), igual que el resto de
  /// la app — no requiere pasarlo desde la presentación.
  Future<void> logActivity({
    required String householdId,
    required String productName,
    required ActivityAction action,
  });

  /// Últimos [limit] eventos del hogar, del más reciente al más antiguo.
  Stream<List<ActivityLogEntry>> watchRecentActivity(
    String householdId, {
    int limit = 20,
  });
}
