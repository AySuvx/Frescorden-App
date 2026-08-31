// lib/data/datasources/firestore_product_datasource.dart
//
// Única clase que habla directamente con Cloud Firestore para operaciones
// de productos. El resto de la app no toca FirebaseFirestore.instance salvo
// esta clase y FirestoreService (mantenido por retrocompatibilidad).
//
// Encapsula:
//  - La ruta 'usuarios/{uid}/productos'
//  - La autenticación (lanza excepción si no hay sesión)
//  - La conversión entre DocumentSnapshot y ProductModel

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';

class FirestoreProductDataSource {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirestoreProductDataSource({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ─── Referencia a la colección del usuario actual ─────────────────────────

  CollectionReference<Map<String, dynamic>> _col() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError(
        'FirestoreProductDataSource: no hay usuario autenticado.',
      );
    }
    return _db.collection('usuarios').doc(user.uid).collection('productos');
  }

  // ─── Lectura ──────────────────────────────────────────────────────────────

  Future<List<ProductModel>> getAll() async {
    final snap = await _col().get();
    return snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return ProductModel.fromMap(data);
    }).toList();
  }

  Future<ProductModel?> findByBarcode(String barcode) async {
    if (barcode.isEmpty) return null;
    final snap =
        await _col().where('barcode', isEqualTo: barcode).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    data['id'] = snap.docs.first.id;
    return ProductModel.fromMap(data);
  }

  Future<ProductModel?> findByName(String name) async {
    if (name.isEmpty) return null;
    final snap =
        await _col().where('name', isEqualTo: name).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    data['id'] = snap.docs.first.id;
    return ProductModel.fromMap(data);
  }

  // ─── Escritura ─────────────────────────────────────────────────────────────

  /// Agrega un documento nuevo y retorna el [ProductModel] con su ID.
  ///
  /// BUG CRÍTICO CORREGIDO (hallado en prueba manual de Fase 3, "Registro a
  /// Granel"): `Product.copyWith()` está declarado en la clase base `Product`
  /// y SIEMPRE construye un `Product` (no hay override en `ProductModel`).
  /// `model.copyWith(id: ref.id) as ProductModel` lanzaba
  /// `type 'Product' is not a subtype of type 'ProductModel'` en every alta
  /// de producto NUEVO (no afectaba ediciones ni el acumulado por
  /// barcode/nombre, que van por `updateProduct`). Preexistente desde Fase 2;
  /// no detectado hasta ahora porque no se había probado un alta nueva
  /// end-to-end desde ese refactor.
  /// FIX: `ProductModel.fromEntity()` reconstruye un `ProductModel` real a
  /// partir del `Product` que retorna `copyWith`, sin cast inseguro.
  Future<ProductModel> add(ProductModel model) async {
    final payload = model.toFirestore()
      ..['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _col().add(payload);
    return ProductModel.fromEntity(model.copyWith(id: ref.id));
  }

  /// Actualiza un documento existente por [docId].
  Future<void> update(String docId, ProductModel model) async {
    await _col().doc(docId).update(model.toFirestore());
  }

  /// Elimina un documento por [docId].
  Future<void> delete(String docId) async {
    await _col().doc(docId).delete();
  }

  /// Actualiza solo la cantidad de un documento ya existente.
  Future<void> updateQuantity(String docId, int newQuantity) async {
    await _col()
        .doc(docId)
        .update({'quantity': newQuantity.toString()});
  }
}
