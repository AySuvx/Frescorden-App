// lib/data/datasources/firestore_product_history_datasource.dart
//
// Única clase que habla directamente con Cloud Firestore para el historial
// de productos resueltos. Colección: usuarios/{uid}/historial (mismo patrón
// de anidación por usuario que FirestoreProductDataSource usa para
// 'productos').
//
// La comparten dos repositorios con propósitos distintos (ISP):
//  - ProductHistoryRepositoryImpl: escribe (logResolution, desde
//    ProductProvider.deleteProduct).
//  - AnalyticsRepositoryImpl: lee (getAll, para calcular AnalyticsSummary).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_history_model.dart';
import '../../domain/entities/product_history_entry.dart';

class FirestoreProductHistoryDataSource {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirestoreProductHistoryDataSource({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _col() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError(
        'FirestoreProductHistoryDataSource: no hay usuario autenticado.',
      );
    }
    return _db.collection('usuarios').doc(user.uid).collection('historial');
  }

  Future<void> add(ProductHistoryEntry entry) async {
    await _col().add(ProductHistoryModel.toFirestore(entry));
  }

  Future<List<ProductHistoryEntry>> getAll() async {
    final snap = await _col().get();
    return snap.docs.map(ProductHistoryModel.fromFirestore).toList();
  }
}
