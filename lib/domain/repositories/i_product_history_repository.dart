// Contrato para registrar productos resueltos (consumidos o desperdiciados,
// ver ProductOutcome). Lo consume ProductProvider.deleteProduct() al
// eliminar un producto. El historial vive por-hogar (households/{id}/
// product_history), igual que el inventario y el log de actividad — regla
// de dependencias de Clean Architecture: domain ← data.

import '../entities/product_history_entry.dart';

abstract interface class IProductHistoryRepository {
  /// Persiste una entrada de historial del hogar [householdId]. La
  /// implementación resuelve `estimatedPrice` si el entry no lo trae (ver
  /// ProductHistoryRepositoryImpl, Opción A: búsqueda en el catálogo de
  /// canastas.json).
  Future<void> logResolution(String householdId, ProductHistoryEntry entry);
}
