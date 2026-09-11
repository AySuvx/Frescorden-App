// lib/data/datasources/firestore_assistant_usage_datasource.dart
//
// Colección '/households/{householdId}/assistant_usage' — un documento por
// consulta exitosa al asistente culinario (append-only, mismo patrón que
// FirestoreActivityLogDataSource). Solo se escribe desde
// AssistantProvider._recordSuccessfulQuery; la lee FirestoreAdminDataSource
// vía collectionGroup para medir adopción global.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreAssistantUsageDataSource {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirestoreAssistantUsageDataSource({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<void> logQuery(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('assistant_usage')
        .add({
      'userId': _auth.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
