import '../../entities/food_category.dart';
import '../../entities/product.dart';
import '../../entities/shopping_item.dart';

/// Cruza la canasta base (más los ítems agregados manualmente) contra el
/// inventario real del hogar y devuelve solo lo que falta por comprar, ya
/// escalado para [personCount] comensales. Sin dependencias externas: es
/// una regla de negocio pura, no requiere repositorio.
class GenerateShoppingListUseCase {
  const GenerateShoppingListUseCase();

  static const _defaultPersonCount = 4;

  List<ShoppingItem> call({
    required List<ShoppingItem> basket,
    required List<ShoppingItem> extraItems,
    required List<Product> inventory,
    required int personCount,
  }) {
    final inventoryNames = inventory.map((p) => p.name.toLowerCase()).toSet();
    final inventoryCategories = inventory.map((p) => p.category).toSet();

    final combined = <String, ShoppingItem>{};
    for (final item in [...basket, ...extraItems]) {
      combined.putIfAbsent(item.name.toLowerCase(), () => item);
    }

    return combined.values
        .where((item) {
          // Ítems genéricos de categoría ("Leche", "Carne" — ver
          // NutritionGroup.suggestedItems): el usuario los cubre con
          // CUALQUIER producto de esa categoría, no solo con ese nombre
          // exacto.
          if (item.matchByCategory) {
            return !inventoryCategories.contains(
              FoodCategory.fromName(item.category),
            );
          }
          return !inventoryNames.contains(item.name.toLowerCase());
        })
        .map((item) => _scaled(item, personCount))
        .toList();
  }

  /// Escala cantidad y precio estimado de [item] según [personCount],
  /// relativo a la línea base del catálogo (`_defaultPersonCount`). Sin
  /// cambios cuando personCount es la línea base, para no introducir ruido
  /// de redondeo en el caso más común.
  ShoppingItem _scaled(ShoppingItem item, int personCount) {
    if (personCount == _defaultPersonCount) return item;
    final ratio = personCount / _defaultPersonCount;
    return ShoppingItem(
      name: item.name,
      quantity: item.quantity * ratio,
      unit: item.unit,
      category: item.category,
      estimatedPrice:
          item.estimatedPrice == null ? null : (item.estimatedPrice! * ratio).round(),
      matchByCategory: item.matchByCategory,
    );
  }
}
