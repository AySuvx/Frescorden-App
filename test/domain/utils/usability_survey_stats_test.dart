// test/domain/utils/usability_survey_stats_test.dart
//
// BDD (Given/When/Then) de UsabilitySurveyStats.compute — agregados puros
// sobre respuestas SUS + NPS (histograma, desglose NPS, promedio por
// ítem), sin depender de Firestore. Ver AdminDashboardScreen para dónde
// se usan estos agregados (gráficos del Panel Administrativo).

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/usability_survey_response.dart';
import 'package:frescorden/domain/utils/usability_survey_stats.dart';

UsabilitySurveyResponse _response({
  required List<int> susAnswers,
  required int npsScore,
}) {
  return UsabilitySurveyResponse(
    uid: 'uid',
    susAnswers: susAnswers,
    npsScore: npsScore,
    submittedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('Historia de Usuario: Como administrador, quiero ver agregados '
      'de la encuesta de usabilidad (SUS + NPS)', () {
    test(
      'Escenario: sin respuestas, no hay nada que agregar',
      () {
        final result = UsabilitySurveyStats.compute(const []);

        expect(result, isNull);
      },
    );

    test(
      'Escenario: una sola respuesta — SUS, histograma e ítems coinciden '
      'con esa única respuesta',
      () {
        // Todas las respuestas "Totalmente de acuerdo" (5) en impares (SUS
        // original) y "Totalmente en desacuerdo" (1) en pares: cada ítem
        // aporta el máximo de 4 puntos -> 10 ítems * 4 * 2.5 = 100.
        final response = _response(
          susAnswers: [5, 1, 5, 1, 5, 1, 5, 1, 5, 1],
          npsScore: 10,
        );

        final result = UsabilitySurveyStats.compute([response]);

        expect(result, isNotNull);
        expect(result!.averageSus, 100.0);
        expect(result.susScoreHistogram, [0, 0, 0, 0, 1]);
        expect(result.promoters, 1);
        expect(result.passives, 0);
        expect(result.detractors, 0);
        expect(result.nps, 100.0);
        expect(result.susItemAverages, [5, 1, 5, 1, 5, 1, 5, 1, 5, 1]);
      },
    );

    test(
      'Escenario: puntaje SUS mínimo (todas las respuestas en el peor '
      'extremo) cae en la primera franja del histograma',
      () {
        // Impares en 1 y pares en 5: cada ítem aporta 0 -> SUS = 0.
        final response = _response(
          susAnswers: [1, 5, 1, 5, 1, 5, 1, 5, 1, 5],
          npsScore: 0,
        );

        final result = UsabilitySurveyStats.compute([response]);

        expect(result!.averageSus, 0.0);
        expect(result.susScoreHistogram, [1, 0, 0, 0, 0]);
        expect(result.detractors, 1);
      },
    );

    test(
      'Escenario: NPS combina promotores, pasivos y detractores con la '
      'fórmula estándar (no es un promedio de las notas crudas)',
      () {
        final neutral = List.filled(10, 3);
        final responses = [
          _response(susAnswers: neutral, npsScore: 9), // promotor
          _response(susAnswers: neutral, npsScore: 10), // promotor
          _response(susAnswers: neutral, npsScore: 7), // pasivo
          _response(susAnswers: neutral, npsScore: 6), // detractor
        ];

        final result = UsabilitySurveyStats.compute(responses);

        expect(result!.promoters, 2);
        expect(result.passives, 1);
        expect(result.detractors, 1);
        // (2 promotores - 1 detractor) / 4 respuestas * 100 = 25.
        expect(result.nps, 25.0);
      },
    );

    test(
      'Escenario: el promedio por ítem se calcula columna por columna, no '
      'fila por fila',
      () {
        final responses = [
          _response(susAnswers: List.filled(10, 1), npsScore: 5),
          _response(susAnswers: List.filled(10, 5), npsScore: 5),
        ];

        final result = UsabilitySurveyStats.compute(responses);

        expect(result!.susItemAverages, List.filled(10, 3.0));
      },
    );
  });
}
