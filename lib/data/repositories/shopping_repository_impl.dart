// lib/data/repositories/shopping_repository_impl.dart
//
// Implementación concreta de IShoppingRepository usando el datasource
// local. Si el origen del catálogo cambia (ej. remoto, con precios
// actualizados por región), solo esta clase cambia.

import '../../domain/entities/budget_tier.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/repositories/i_shopping_repository.dart';
import '../datasources/shopping_local_datasource.dart';

class ShoppingRepositoryImpl implements IShoppingRepository {
  final ShoppingLocalDataSource _dataSource;

  ShoppingRepositoryImpl(this._dataSource);

  @override
  Future<List<ShoppingItem>> getBasket(BudgetTier tier) {
    return _dataSource.getBasket(tier);
  }
}
