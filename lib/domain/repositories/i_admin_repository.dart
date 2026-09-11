// lib/domain/repositories/i_admin_repository.dart
//
// Contrato del Panel Administrativo Global. Regla de dependencias de Clean
// Architecture: domain ← data.

import '../entities/admin_stats.dart';

abstract interface class IAdminRepository {
  /// Métricas globales de toda la app. Solo debe invocarse con la sesión
  /// del usuario administrador (ver kAdminUid) — un usuario normal recibirá
  /// un error de permisos de Firestore, ya que las reglas restringen estas
  /// consultas agregadas al UID admin.
  Future<AdminStats> getGlobalStats();
}
