// Cálculo puro de agregados sobre respuestas de la encuesta de usabilidad
// (SUS + NPS) — separado de FirestoreAdminDataSource para que esta lógica
// se pueda probar sin depender de Firestore (solo necesita las entidades
// de dominio UsabilitySurveyResponse, no QuerySnapshot).

import '../entities/usability_survey_response.dart';

class UsabilitySurveyStats {
  /// Puntaje SUS promedio (0-100) de todas las respuestas.
  final double averageSus;

  /// Índice NPS (-100 a 100): fórmula estándar % promotores - %
  /// detractores. NO es un promedio de las notas 0-10 — ver
  /// [UsabilitySurveyResponse.npsScore].
  final double nps;

  /// Distribución de puntajes SUS en 5 franjas de 20 puntos: [0-20),
  /// [20-40), [40-60), [60-80), [80-100].
  final List<int> susScoreHistogram;

  /// Conteos NPS por categoría: promotor (9-10), pasivo (7-8), detractor
  /// (0-6). Suman el total de respuestas.
  final int promoters;
  final int passives;
  final int detractors;

  /// Promedio (escala Likert 1-5) de cada uno de los 10 ítems del SUS, en
  /// el mismo orden del instrumento.
  final List<double> susItemAverages;

  const UsabilitySurveyStats({
    required this.averageSus,
    required this.nps,
    required this.susScoreHistogram,
    required this.promoters,
    required this.passives,
    required this.detractors,
    required this.susItemAverages,
  });

  /// `null` si [responses] está vacío — no hay nada que agregar todavía.
  static UsabilitySurveyStats? compute(
    List<UsabilitySurveyResponse> responses,
  ) {
    if (responses.isEmpty) return null;

    final susScores = responses.map((r) => r.susScore).toList();
    final averageSus = susScores.reduce((a, b) => a + b) / susScores.length;

    // Un puntaje de exactamente 100 cae en la última franja (clamp).
    final histogram = List<int>.filled(5, 0);
    for (final score in susScores) {
      final bucket = (score / 20).floor().clamp(0, 4);
      histogram[bucket]++;
    }

    var promoters = 0;
    var passives = 0;
    var detractors = 0;
    for (final response in responses) {
      if (response.npsScore >= 9) {
        promoters++;
      } else if (response.npsScore <= 6) {
        detractors++;
      } else {
        passives++;
      }
    }
    final nps = (promoters - detractors) / responses.length * 100;

    final itemCount = responses.first.susAnswers.length;
    final itemAverages = List<double>.generate(itemCount, (i) {
      final sum = responses.fold<int>(0, (acc, r) => acc + r.susAnswers[i]);
      return sum / responses.length;
    });

    return UsabilitySurveyStats(
      averageSus: averageSus,
      nps: nps,
      susScoreHistogram: histogram,
      promoters: promoters,
      passives: passives,
      detractors: detractors,
      susItemAverages: itemAverages,
    );
  }
}
