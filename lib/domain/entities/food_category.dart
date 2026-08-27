// lib/domain/entities/food_category.dart
//
// PASO 2 — Categorización de Alimentos (#1):
// Enum de dominio con las categorías disponibles para clasificar un
// producto. Vive en `domain` porque es una regla de negocio (qué
// categorías existen), no un detalle de UI ni de persistencia.
// Sin dependencias de Flutter (igual que AppUser): el ícono de cada
// categoría se mapea en la capa de presentación
// (presentation/utils/food_category_ui.dart), no aquí.

enum FoodCategory {
  lacteos,
  carnesYEmbutidos,
  frutasYVerduras,
  granosYCereales,
  panaderia,
  bebidas,
  congelados,
  condimentosYSalsas,
  enlatadosYConservas,
  otros;

  /// Etiqueta legible para mostrar en la UI.
  String get label {
    switch (this) {
      case FoodCategory.lacteos:
        return 'Lácteos';
      case FoodCategory.carnesYEmbutidos:
        return 'Carnes y embutidos';
      case FoodCategory.frutasYVerduras:
        return 'Frutas y verduras';
      case FoodCategory.granosYCereales:
        return 'Granos y cereales';
      case FoodCategory.panaderia:
        return 'Panadería';
      case FoodCategory.bebidas:
        return 'Bebidas';
      case FoodCategory.congelados:
        return 'Congelados';
      case FoodCategory.condimentosYSalsas:
        return 'Condimentos y salsas';
      case FoodCategory.enlatadosYConservas:
        return 'Enlatados y conservas';
      case FoodCategory.otros:
        return 'Otros';
    }
  }

  /// Reconstruye una [FoodCategory] a partir del nombre guardado en
  /// Firestore ([FoodCategory.name]). Si el valor es nulo, vacío o no
  /// coincide con ninguna categoría conocida (documentos legacy creados
  /// antes de esta fase), retorna [FoodCategory.otros] en vez de fallar.
  static FoodCategory fromName(String? name) {
    if (name == null || name.isEmpty) return FoodCategory.otros;
    return FoodCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => FoodCategory.otros,
    );
  }
}
