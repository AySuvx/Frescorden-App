// Implementación de IProductHistoryReader sobre
// FirestoreProductHistoryDataSource — mismo datasource que
// AnalyticsRepositoryImpl, para la misma colección, pero expuesto por su
// propio contrato de solo lectura (ver IProductHistoryReader).

import '../../domain/entities/product_history_entry.dart';
import '../../domain/repositories/i_product_history_reader.dart';
import '../datasources/firestore_product_history_datasource.dart';

class ProductHistoryReaderImpl implements IProductHistoryReader {
  final FirestoreProductHistoryDataSource _dataSource;

  ProductHistoryReaderImpl(this._dataSource);

  @override
  Future<List<ProductHistoryEntry>> getAll(String householdId) {
    return _dataSource.getAll(householdId);
  }
}
