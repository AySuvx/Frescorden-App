// lib/domain/repositories/i_shopping_repository.dart
//
// Contrato (interfaz) que define QUÉ canasta básica corresponde a cada
// nivel de presupuesto, sin especificar CÓMO se obtiene. Regla de
// dependencias de Clean Architecture: domain ← data.

import '../entities/budget_tier.dart';
import '../entities/shopping_item.dart';

abstract interface class IShoppingRepository {
  /// Canasta base (catálogo crudo, sin cruzar con inventario) para el
  /// nivel de presupuesto indicado.
  Future<List<ShoppingItem>> getBasket(BudgetTier tier);
}
