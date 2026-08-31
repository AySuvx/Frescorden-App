// lib/domain/repositories/i_product_history_repository.dart
//
// Contrato para registrar productos resueltos (consumidos a tiempo o
// vencidos). Lo consume ProductProvider.deleteProduct() al eliminar un
// producto. Regla de dependencias de Clean Architecture: domain ← data.

import '../entities/product_history_entry.dart';

abstract interface class IProductHistoryRepository {
  /// Persiste una entrada de historial. La implementación resuelve
  /// `estimatedPrice` si el entry no lo trae (ver ProductHistoryRepositoryImpl,
  /// Opción A: búsqueda en el catálogo de canastas.json).
  Future<void> logResolution(ProductHistoryEntry entry);
}
