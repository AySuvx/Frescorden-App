// Contrato para la encuesta de usabilidad (SUS + NPS) del piloto — ver
// UsabilitySurveyResponse. Una respuesta por usuario (no por hogar): la
// usabilidad percibida es individual, no se comparte entre miembros de un
// mismo hogar.

import '../entities/usability_survey_response.dart';

abstract interface class IUsabilitySurveyRepository {
  /// `true` si [uid] ya respondió la encuesta — para no volver a
  /// ofrecérsela automáticamente (sigue disponible manualmente desde el
  /// menú si quiere responderla de nuevo).
  Future<bool> hasSubmitted(String uid);

  Future<void> submit(UsabilitySurveyResponse response);

  /// Todas las respuestas — solo para el Panel Administrativo (ver
  /// firestore.rules: lectura de la colección completa restringida al
  /// admin).
  Future<List<UsabilitySurveyResponse>> getAll();
}
