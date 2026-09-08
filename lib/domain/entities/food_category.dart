// lib/domain/entities/food_category.dart
//
// Categorización de Alimentos (#1):
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
  otros,

  /// Catálogo ampliado (Fase 4.5): `frutasYVerduras` combinaba ambas.
  /// Se agregan por separado para el selector nuevo — `frutasYVerduras` se
  /// conserva (no se borra ni renombra) para que los productos ya
  /// guardados con esa categoría sigan resolviendo bien con [fromName];
  /// solo queda fuera de [selectable] para no listarla dos veces.
  frutas,
  verdurasYHortalizas;

  /// Etiqueta legible para mostrar en la UI.
  String get label {
    switch (this) {
      case FoodCategory.lacteos:
        return 'Lácteos';
      case FoodCategory.carnesYEmbutidos:
        return 'Carnes y aves';
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
        return 'Condimentos y especias';
      case FoodCategory.enlatadosYConservas:
        return 'Enlatados y conservas';
      case FoodCategory.otros:
        return 'Otros';
      case FoodCategory.frutas:
        return 'Frutas';
      case FoodCategory.verdurasYHortalizas:
        return 'Verduras y hortalizas';
    }
  }

  /// Categorías que se ofrecen para elegir (selector de "Por Categoría",
  /// filtros, formulario). Excluye `frutasYVerduras`: es la categoría
  /// combinada legacy, ya reemplazada por `frutas`/`verdurasYHortalizas`
  /// por separado — se mantiene solo para no romper productos existentes.
  static List<FoodCategory> get selectable =>
      values.where((c) => c != FoodCategory.frutasYVerduras).toList();

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
