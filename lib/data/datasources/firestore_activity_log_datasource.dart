// lib/data/datasources/firestore_activity_log_datasource.dart
//
// Colección '/households/{householdId}/activity_log' — log de auditoría
// de solo escritura (append-only, ver firestore.rules: update/delete
// deniegan siempre). El usuario que registra cada evento se resuelve acá
// vía FirebaseAuth.instance.currentUser, igual que el resto de la app.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/activity_log_entry.dart';
import '../models/activity_log_model.dart';

class FirestoreActivityLogDataSource {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirestoreActivityLogDataSource({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _col(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('activity_log');
  }

  Future<void> logActivity({
    required String householdId,
    required String productName,
    required ActivityAction action,
  }) {
    final user = _auth.currentUser;
    final model = ActivityLogModel(
      productName: productName,
      action: action,
      userEmail: user?.email,
      timestamp: DateTime.now(), // ignorado al escribir; ver toJson
    );
    return _col(householdId).add(model.toJson(userId: user?.uid));
  }

  Stream<List<ActivityLogEntry>> watchRecentActivity(
    String householdId, {
    int limit = 20,
  }) {
    return _col(householdId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(ActivityLogModel.fromFirestore).toList());
  }
}
