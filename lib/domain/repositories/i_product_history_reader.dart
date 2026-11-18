// Contrato de solo lectura sobre el historial de productos resueltos de un
// hogar — lo que RestockPredictionProvider necesita para predecir
// reposición (ver PredictRestockUseCase). Separado de
// IProductHistoryRepository (que es de solo escritura, usado por
// ProductProvider para registrar una resolución) porque ningún consumidor
// necesita ambas operaciones a la vez. Regla de dependencias de Clean
// Architecture: domain ← data.

import '../entities/product_history_entry.dart';

abstract interface class IProductHistoryReader {
  /// Todo el historial resuelto (consumido o desperdiciado) del hogar
  /// [householdId], sin acotar por fecha — quien llama decide la ventana.
  Future<List<ProductHistoryEntry>> getAll(String householdId);
}
