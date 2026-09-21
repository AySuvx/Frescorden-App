// Ítem de la canasta básica de un [BudgetTier]: nombre, cantidad, unidad y
// precio estimado — necesario para sumar un costo total y compararlo
// contra el presupuesto.
//
// `estimatedPrice` es opcional: si el catálogo local no trae precio para
// un ítem, ese ítem simplemente no aporta al total estimado (no rompe el
// cálculo, ver ShoppingProvider.estimatedTotalFor).

class ShoppingItem {
  final String name;
  final num quantity;
  final String unit;
  final String category;

  /// Precio estimado en COP para la cantidad indicada (no por unidad).
  /// Opcional porque no todos los ítems del catálogo tienen un precio de
  /// referencia cargado todavía.
  final int? estimatedPrice;

  /// `true` cuando [name] es un genérico de categoría ("Leche", "Carne",
  /// "Verduras" — ver NutritionGroup.suggestedItems), no un producto
  /// puntual. Solo esos ítems son seguros de cruzar contra el inventario
  /// por [FoodCategory] en vez de por nombre exacto (ver
  /// ShoppingProvider.missingItems): un ítem específico como "Aceite de
  /// oliva" NO debe marcarse como "ya lo tienes" solo porque el usuario
  /// tiene sal (misma categoría condimentosYSalsas, producto distinto).
  final bool matchByCategory;

  const ShoppingItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.estimatedPrice,
    this.matchByCategory = false,
  });

  @override
  String toString() =>
      'ShoppingItem($quantity $unit $name, ~\$${estimatedPrice ?? '?'})';
}
