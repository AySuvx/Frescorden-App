// lib/domain/entities/shopping_item.dart
//
// FASE 2 (Fresc-O-rden) — Módulo de Compras Inteligentes:
// Ítem de la canasta básica de un [BudgetTier]. Reemplaza los Strings
// sueltos ('Arroz 5kg', 'Huevos 30 unidades', ...) del mock original por
// una estructura con cantidad, unidad y precio estimado — necesaria para
// poder sumar un costo total y compararlo contra el presupuesto.
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

  const ShoppingItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.estimatedPrice,
  });

  @override
  String toString() =>
      'ShoppingItem($quantity $unit $name, ~\$${estimatedPrice ?? '?'})';
}
