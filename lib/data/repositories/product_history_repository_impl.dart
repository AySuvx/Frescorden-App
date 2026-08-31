// lib/data/repositories/product_history_repository_impl.dart
//
// Implementación de IProductHistoryRepository. Antes de persistir, resuelve
// `estimatedPrice` cuando el entry no lo trae — Opción A aprobada: busca el
// nombre del producto (case-insensitive) en el catálogo local de canastas
// (mismo catálogo que usa el módulo de Compras — ver ShoppingLocalDataSource)
// y usa el precio de la primera coincidencia. Si no hay coincidencia, el
// entry se guarda sin precio: no rompe el cálculo de AnalyticsSummary, solo
// hace que ese ítem no aporte a `moneySavedCop` (ver GetAnalyticsUseCase).

import '../../domain/entities/product_history_entry.dart';
import '../../domain/repositories/i_product_history_repository.dart';
import '../datasources/firestore_product_history_datasource.dart';
import '../datasources/shopping_local_datasource.dart';
import '../../domain/entities/budget_tier.dart';

class ProductHistoryRepositoryImpl implements IProductHistoryRepository {
  final FirestoreProductHistoryDataSource _dataSource;
  final ShoppingLocalDataSource _priceCatalog;

  ProductHistoryRepositoryImpl(this._dataSource, this._priceCatalog);

  @override
  Future<void> logResolution(ProductHistoryEntry entry) async {
    final toSave = entry.estimatedPrice != null
        ? entry
        : entry.copyWith(estimatedPrice: await _estimatePrice(entry.name));
    await _dataSource.add(toSave);
  }

  /// Busca `name` (case-insensitive) en las 3 canastas del catálogo local.
  /// Retorna el primer precio encontrado, o `null` si no hay coincidencia.
  Future<int?> _estimatePrice(String name) async {
    final target = name.trim().toLowerCase();
    if (target.isEmpty) return null;

    for (final tier in BudgetTier.values) {
      final basket = await _priceCatalog.getBasket(tier);
      for (final item in basket) {
        if (item.name.toLowerCase() == target && item.estimatedPrice != null) {
          return item.estimatedPrice;
        }
      }
    }
    return null;
  }
}
