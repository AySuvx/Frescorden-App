// lib/domain/repositories/i_product_repository.dart
//
// Contrato (interfaz) que define QUÉ puede hacerse con productos,
// sin especificar CÓMO. El dominio depende de esta abstracción;
// la implementación real (Firestore, local, mock) vive en lib/data/.
//
// Regla de dependencias de Clean Architecture:
//   domain ← data (data implementa domain, no al revés)

import '../entities/product.dart';

abstract interface class IProductRepository {
  /// Carga todos los productos del usuario autenticado (one-shot).
  Future<List<Product>> getProducts();

  /// Agrega un producto nuevo. Devuelve el [Product] con su ID asignado.
  Future<Product> addProduct(Product product);

  /// Actualiza un producto existente identificado por [Product.id].
  Future<void> updateProduct(Product product);

  /// Elimina el producto con el [id] indicado.
  Future<void> deleteProduct(String id);

  /// Busca el primer producto que tenga el [barcode] indicado.
  /// Retorna `null` si no existe.
  Future<Product?> findByBarcode(String barcode);

  /// Busca el primer producto cuyo nombre coincida exactamente con [name].
  /// Retorna `null` si no existe.
  Future<Product?> findByName(String name);
}
