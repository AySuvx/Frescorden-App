// Contrato (interfaz) que define QUÉ canasta básica corresponde a cada
// nivel de presupuesto, sin especificar CÓMO se obtiene. Regla de
// dependencias de Clean Architecture: domain ← data.

import '../entities/budget_tier.dart';
import '../entities/shopping_item.dart';

abstract interface class IShoppingRepository {
  /// Canasta base (catálogo crudo, sin cruzar con inventario) para el
  /// nivel de presupuesto indicado.
  Future<List<ShoppingItem>> getBasket(BudgetTier tier);

  /// Ítems "extra" cacheados localmente (agregados a mano, desde "Plato
  /// Equilibrado" o desde una receta — ver ShoppingProvider._extraItems),
  /// que no forman parte del catálogo de [getBasket].
  Future<List<ShoppingItem>> loadExtraItems();

  /// Persiste el estado actual de los ítems "extra" (ver [loadExtraItems]).
  Future<void> saveExtraItems(List<ShoppingItem> items);
}
