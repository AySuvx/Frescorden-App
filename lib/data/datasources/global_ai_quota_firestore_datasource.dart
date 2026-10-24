// Colección '/global_ai_quota/{yyyy-MM-dd}' (fecha UTC) — un único
// contador `count` por día, compartido por todos los dispositivos. Ver
// firestore.rules: cualquier autenticado puede leer, y solo puede
// incrementar de a 1 (nunca pisar el contador con un valor arbitrario).

import 'package:cloud_firestore/cloud_firestore.dart';

class GlobalAiQuotaFirestoreDataSource {
  final FirebaseFirestore _db;

  GlobalAiQuotaFirestoreDataSource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String dateId) =>
      _db.collection('global_ai_quota').doc(dateId);

  Future<int> getCount(String dateId) async {
    final snapshot = await _doc(dateId).get();
    return (snapshot.data()?['count'] as num?)?.toInt() ?? 0;
  }

  /// Incrementa el contador del día en 1 (crea el documento si es la
  /// primera consulta del día) y devuelve el nuevo total.
  Future<int> incrementAndGetCount(String dateId) async {
    await _doc(dateId).set({
      'count': FieldValue.increment(1),
    }, SetOptions(merge: true));
    return getCount(dateId);
  }
}
