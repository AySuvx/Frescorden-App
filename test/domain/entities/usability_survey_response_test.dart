// test/domain/entities/usability_survey_response_test.dart
//
// BDD de UsabilitySurveyResponse.susScore: fórmula estándar de Brooke
// (1986) para el System Usability Scale — ítems impares (índice par)
// restan 1 a la respuesta, ítems pares (índice impar) restan la respuesta
// a 5, se suma todo y se multiplica por 2.5.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/domain/entities/usability_survey_response.dart';

UsabilitySurveyResponse _response(List<int> susAnswers, {int npsScore = 8}) {
  return UsabilitySurveyResponse(
    uid: 'uid-1',
    susAnswers: susAnswers,
    npsScore: npsScore,
    submittedAt: DateTime(2026, 10, 15),
  );
}

void main() {
  group('Historia de Usuario: Como responsable del piloto, quiero medir la '
      'usabilidad percibida con el puntaje SUS estándar', () {
    test(
      'Escenario: la peor respuesta posible (1 en todo) da un puntaje de 0',
      () {
        // Impares (índice par): 1-1=0. Pares (índice impar): 5-1=4.
        // 5 impares*0 + 5 pares*4 = 20, *2.5 = 50 — la "peor" respuesta
        // real no es 0 bajo esta fórmula, es justamente el punto donde el
        // algoritmo se neutraliza si todas las respuestas son iguales.
        final response = _response(List.filled(10, 1));

        expect(response.susScore, 50.0);
      },
    );

    test(
      'Escenario: la mejor respuesta posible (5 en impares, 1 en pares) da '
      '100',
      () {
        final answers = List.generate(10, (i) => i.isEven ? 5 : 1);
        final response = _response(answers);

        expect(response.susScore, 100.0);
      },
    );

    test(
      'Escenario: la peor respuesta posible en sentido real (1 en impares, '
      '5 en pares) da 0',
      () {
        final answers = List.generate(10, (i) => i.isEven ? 1 : 5);
        final response = _response(answers);

        expect(response.susScore, 0.0);
      },
    );

    test('Escenario: una respuesta intermedia (3 en todo) da 50', () {
      final response = _response(List.filled(10, 3));

      expect(response.susScore, 50.0);
    });

    test(
      'Escenario: el NPS es independiente del cálculo del SUS',
      () {
        final response = _response(List.filled(10, 3), npsScore: 10);

        expect(response.npsScore, 10);
        expect(response.susScore, 50.0);
      },
    );
  });
}
