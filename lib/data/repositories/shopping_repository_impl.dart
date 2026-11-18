// Implementación concreta de IShoppingRepository usando el datasource
// local. Si el origen del catálogo cambia (ej. remoto, con precios
// actualizados por región), solo esta clase cambia.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/budget_tier.dart';
import '../../domain/entities/shopping_item.dart';
import '../../domain/repositories/i_shopping_repository.dart';
import '../datasources/shopping_local_datasource.dart';
import '../models/shopping_item_model.dart';

class ShoppingRepositoryImpl implements IShoppingRepository {
  final ShoppingLocalDataSource _dataSource;

  ShoppingRepositoryImpl(this._dataSource);

  static const _kExtraItemsKey = 'shopping_extra_items';

  @override
  Future<List<ShoppingItem>> getBasket(BudgetTier tier) {
    return _dataSource.getBasket(tier);
  }

  @override
  Future<List<ShoppingItem>> loadExtraItems() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kExtraItemsKey) ?? const [])
        .map(
          (raw) =>
              ShoppingItemModel.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<void> saveExtraItems(List<ShoppingItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kExtraItemsKey,
      items.map((item) => jsonEncode(ShoppingItemModel.toJson(item))).toList(),
    );
  }
}
