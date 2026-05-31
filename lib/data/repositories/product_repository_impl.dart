// lib/data/repositories/product_repository_impl.dart
//
// Implementación concreta de IProductRepository usando Firestore.
// Traduce entre la entidad de dominio (Product) y el modelo de datos
// (ProductModel), y delega todas las operaciones al DataSource.
//
// Si en el futuro se necesita un repositorio de pruebas (mock) o uno
// local (SQLite), basta con crear otra clase que implemente IProductRepository
// sin tocar ninguna pantalla ni proveedor.

import '../../domain/entities/product.dart';
import '../../domain/repositories/i_product_repository.dart';
import '../datasources/firestore_product_datasource.dart';
import '../models/product_model.dart';

class ProductRepositoryImpl implements IProductRepository {
  final FirestoreProductDataSource _dataSource;

  ProductRepositoryImpl(this._dataSource);

  @override
  Future<List<Product>> getProducts() {
    return _dataSource.getAll();
  }

  @override
  Future<Product> addProduct(Product product) async {
    final model = ProductModel.fromEntity(product);
    return _dataSource.add(model);
  }

  @override
  Future<void> updateProduct(Product product) {
    final model = ProductModel.fromEntity(product);
    return _dataSource.update(product.id, model);
  }

  @override
  Future<void> deleteProduct(String id) {
    return _dataSource.delete(id);
  }

  @override
  Future<Product?> findByBarcode(String barcode) {
    return _dataSource.findByBarcode(barcode);
  }

  @override
  Future<Product?> findByName(String name) {
    return _dataSource.findByName(name);
  }
}
