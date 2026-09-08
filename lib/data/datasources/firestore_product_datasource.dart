// lib/data/datasources/firestore_product_datasource.dart
//
// Única clase que habla directamente con Cloud Firestore para operaciones
// de productos. El resto de la app no toca FirebaseFirestore.instance salvo
// esta clase y FirestoreService (mantenido por retrocompatibilidad).
//
// Módulo de Grupos Familiares (Household): la ruta pasó de
// 'usuarios/{uid}/productos' (por usuario) a
// 'households/{householdId}/productos' (compartida por todo el hogar) —
// así todos los miembros ven y editan el mismo inventario en tiempo real
// (ver watchAll). El [householdId] llega explícito desde arriba
// (ProductRepositoryImpl ← ProductProvider ← HouseholdProvider); esta
// clase ya no resuelve el usuario actual internamente.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class FirestoreProductDataSource {
  final FirebaseFirestore _db;

  FirestoreProductDataSource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ─── Referencia a la colección del hogar ───────────────────────────────

  CollectionReference<Map<String, dynamic>> _col(String householdId) {
    return _db.collection('households').doc(householdId).collection('productos');
  }

  // ─── Lectura en tiempo real ─────────────────────────────────────────────

  /// Emite la lista completa de productos del hogar cada vez que cambia en
  /// Firestore — de este dispositivo o de cualquier otro miembro.
  Stream<List<ProductModel>> watchAll(String householdId) {
    return _col(householdId).snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ProductModel.fromMap(data);
      }).toList();
    });
  }

  // ─── Lectura puntual ──────────────────────────────────────────────────────

  Future<ProductModel?> findByBarcode(String householdId, String barcode) async {
    if (barcode.isEmpty) return null;
    final snap = await _col(householdId)
        .where('barcode', isEqualTo: barcode)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    data['id'] = snap.docs.first.id;
    return ProductModel.fromMap(data);
  }

  Future<ProductModel?> findByName(String householdId, String name) async {
    if (name.isEmpty) return null;
    final snap =
        await _col(householdId).where('name', isEqualTo: name).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    data['id'] = snap.docs.first.id;
    return ProductModel.fromMap(data);
  }

  // ─── Escritura ─────────────────────────────────────────────────────────────

  /// Agrega un documento nuevo y retorna el [ProductModel] con su ID.
  ///
  /// BUG CRÍTICO CORREGIDO (hallado en prueba manual en dispositivo,
  /// "Registro a Granel"): `Product.copyWith()` está declarado en la clase
  /// base `Product` y SIEMPRE construye un `Product` (no hay override en
  /// `ProductModel`). `model.copyWith(id: ref.id) as ProductModel` lanzaba
  /// `type 'Product' is not a subtype of type 'ProductModel'` en every alta
  /// de producto NUEVO (no afectaba ediciones ni el acumulado por
  /// barcode/nombre, que van por `updateProduct`). Bug preexistente; no
  /// detectado hasta ahora porque no se había probado un alta nueva
  /// end-to-end desde el refactor que lo introdujo.
  /// FIX: `ProductModel.fromEntity()` reconstruye un `ProductModel` real a
  /// partir del `Product` que retorna `copyWith`, sin cast inseguro.
  Future<ProductModel> add(String householdId, ProductModel model) async {
    final payload = model.toFirestore()
      ..['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _col(householdId).add(payload);
    return ProductModel.fromEntity(model.copyWith(id: ref.id));
  }

  /// Actualiza un documento existente por [docId].
  Future<void> update(String householdId, String docId, ProductModel model) async {
    await _col(householdId).doc(docId).update(model.toFirestore());
  }

  /// Elimina un documento por [docId].
  Future<void> delete(String householdId, String docId) async {
    await _col(householdId).doc(docId).delete();
  }

  /// Actualiza solo la cantidad de un documento ya existente.
  Future<void> updateQuantity(
    String householdId,
    String docId,
    int newQuantity,
  ) async {
    await _col(householdId).doc(docId).update({'quantity': newQuantity.toString()});
  }
}
