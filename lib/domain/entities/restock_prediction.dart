// Predicción "se te puede estar acabando X" basada en cada cuánto el hogar
// suele volver a registrar ese mismo producto — ver PredictRestockUseCase.
// No usa IA: es aritmética simple sobre el historial que la app ya guarda.

import 'food_category.dart';

class RestockPrediction {
  final String productName;
  final FoodCategory category;

  /// Unidad del producto actual en inventario (ej. "kg", "unidades") — para
  /// precargar el formulario de "Agregar de nuevo" sin que el usuario
  /// tenga que volver a escribirla (ver InicioScreen).
  final String unit;

  /// Promedio de días entre una entrada de este producto y la siguiente,
  /// calculado sobre el historial del hogar.
  final int averageCycleDays;

  /// Días desde que el producto actual en inventario se registró.
  final int daysSinceEntry;

  const RestockPrediction({
    required this.productName,
    required this.category,
    required this.unit,
    required this.averageCycleDays,
    required this.daysSinceEntry,
  });

  /// `>= 1` cuando ya se cumplió (o superó) el ciclo habitual — mientras
  /// más alto, más atrasado va respecto a su propio patrón de compra.
  double get urgency =>
      averageCycleDays == 0 ? 1 : daysSinceEntry / averageCycleDays;
}
