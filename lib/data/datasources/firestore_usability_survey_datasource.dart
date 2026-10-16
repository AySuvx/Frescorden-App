// Colección raíz '/usability_surveys/{uid}' — una respuesta por usuario
// (el uid es el ID del documento, no un campo: así `set` siempre
// sobreescribe la respuesta anterior de la misma persona en vez de crear
// duplicados si decide responder de nuevo).

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usability_survey_model.dart';

class FirestoreUsabilitySurveyDataSource {
  final FirebaseFirestore _db;

  FirestoreUsabilitySurveyDataSource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('usability_surveys');

  Future<bool> hasSubmitted(String uid) async {
    final doc = await _col.doc(uid).get();
    return doc.exists;
  }

  Future<void> submit(String uid, UsabilitySurveyModel model) {
    return _col.doc(uid).set(model.toJson());
  }

  Future<List<UsabilitySurveyModel>> getAll() async {
    final snap = await _col.get();
    return snap.docs.map(UsabilitySurveyModel.fromFirestore).toList();
  }
}
