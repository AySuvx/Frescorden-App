// Única clase que habla directamente con Cloud Firestore para el historial
// de productos resueltos. Colección: households/{householdId}/
// product_history — por-hogar, mismo patrón de anidación que
// FirestoreProductDataSource usa para 'productos' y
// FirestoreActivityLogDataSource para 'activity_log'.
//
// La comparten dos repositorios con propósitos distintos (ISP):
//  - ProductHistoryRepositoryImpl: escribe (logResolution, desde
//    ProductProvider.deleteProduct).
//  - AnalyticsRepositoryImpl: lee (getAll, para calcular AnalyticsSummary).

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_history_model.dart';
import '../../domain/entities/product_history_entry.dart';

class FirestoreProductHistoryDataSource {
  final FirebaseFirestore _db;

  FirestoreProductHistoryDataSource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('product_history');
  }

  Future<void> add(String householdId, ProductHistoryEntry entry) async {
    await _col(householdId).add(ProductHistoryModel.toFirestore(entry));
  }

  Future<List<ProductHistoryEntry>> getAll(String householdId) async {
    final snap = await _col(householdId).get();
    return snap.docs.map(ProductHistoryModel.fromFirestore).toList();
  }
}
