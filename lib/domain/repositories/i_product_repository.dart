// lib/domain/repositories/i_product_repository.dart
//
// Contrato (interfaz) que define QUÉ puede hacerse con productos,
// sin especificar CÓMO. El dominio depende de esta abstracción;
// la implementación real (Firestore, local, mock) vive en lib/data/.
//
// Regla de dependencias de Clean Architecture:
//   domain ← data (data implementa domain, no al revés)
//
// Módulo de Grupos Familiares (Household): el inventario pasó de ser
// por-usuario a ser por-hogar. Todos los métodos reciben [householdId]
// explícito en vez de resolver el usuario internamente (como hacía la
// versión anterior con FirebaseAuth.instance.currentUser) — el dominio no
// debe saber CÓMO se determina el hogar activo, solo QUE se le pasa uno.

import '../entities/product.dart';

abstract interface class IProductRepository {
  /// Emite la lista completa de productos del hogar [householdId] cada vez
  /// que cambia en Firestore (alta, baja o modificación) — propia o de
  /// cualquier otro miembro del hogar, desde cualquier dispositivo.
  Stream<List<Product>> watchProducts(String householdId);

  /// Agrega un producto nuevo al hogar [householdId]. Devuelve el
  /// [Product] con su ID asignado.
  Future<Product> addProduct(String householdId, Product product);

  /// Actualiza un producto existente identificado por [Product.id] dentro
  /// del hogar [householdId].
  Future<void> updateProduct(String householdId, Product product);

  /// Elimina el producto con el [id] indicado dentro del hogar
  /// [householdId].
  Future<void> deleteProduct(String householdId, String id);

  /// Busca el primer producto del hogar [householdId] que tenga el
  /// [barcode] indicado. Retorna `null` si no existe.
  Future<Product?> findByBarcode(String householdId, String barcode);

  /// Busca el primer producto del hogar [householdId] cuyo nombre
  /// coincida exactamente con [name]. Retorna `null` si no existe.
  Future<Product?> findByName(String householdId, String name);
}
