// lib/Services/firestore_service.dart
//
// BUG #3 CORREGIDO: La colección raíz 'productos' fue reemplazada por
// la ruta correcta 'usuarios/{uid}/productos', alineándola con el resto
// de la app. Se añadió verificación de autenticación antes de escribir.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Devuelve la referencia a la sub-colección de productos del usuario actual.
  /// Lanza [Exception] si no hay sesión activa.
  CollectionReference<Map<String, dynamic>> _productosRef() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(
        'FirestoreService: no hay usuario autenticado. '
        'Asegúrate de llamar este método solo cuando el usuario haya iniciado sesión.',
      );
    }
    return _db
        .collection('usuarios')
        .doc(user.uid)
        .collection('productos');
  }

  /// Guarda un producto nuevo en Firestore bajo el usuario autenticado.
  Future<DocumentReference> guardarProducto(
    Map<String, dynamic> producto,
  ) async {
    return _productosRef().add({
      'name': producto['name'],
      'quantity': producto['quantity'],
      'unit': producto['unit'] ?? 'unidad',
      'expirationDate': producto['expirationDate'],
      'barcode': producto['barcode'],
      'imagePath': producto['imagePath'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Actualiza un producto existente por su [docId].
  Future<void> actualizarProducto(
    String docId,
    Map<String, dynamic> campos,
  ) async {
    await _productosRef().doc(docId).update(campos);
  }

  /// Elimina un producto por su [docId].
  Future<void> eliminarProducto(String docId) async {
    await _productosRef().doc(docId).delete();
  }

  /// Retorna todos los productos del usuario como stream reactivo.
  Stream<QuerySnapshot<Map<String, dynamic>>> productosStream() {
    return _productosRef().snapshots();
  }

  /// Carga puntual de todos los productos (one-shot).
  Future<List<Map<String, dynamic>>> cargarProductos() async {
    final snapshot = await _productosRef().get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}
