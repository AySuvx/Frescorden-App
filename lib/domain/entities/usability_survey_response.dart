// Respuesta de un usuario al System Usability Scale (SUS, Brooke 1986) +
// una pregunta de Net Promoter Score (NPS) aparte. Son dos instrumentos
// académicos distintos que NO se mezclan en un solo cálculo: el SUS mide
// usabilidad percibida (facilidad, consistencia, confianza, aprendizaje);
// el NPS mide qué tan dispuesto está a recomendar la app — ver
// UsabilitySurveyScreen para el texto exacto de cada ítem.

class UsabilitySurveyResponse {
  final String uid;

  /// Las 10 respuestas del SUS, en orden (1-5 cada una, escala Likert de
  /// "Totalmente en desacuerdo" a "Totalmente de acuerdo"). Índice 0 =
  /// ítem 1, ... índice 9 = ítem 10 — mismo orden que el instrumento
  /// original, no se reordenan ni se omiten (ver nota en
  /// UsabilitySurveyScreen sobre por qué no se puede acortar el SUS).
  final List<int> susAnswers;

  /// "¿Qué tan probable es que recomiendes Fresc(o)rden a un familiar o
  /// amigo?" — escala 0 a 10 (Net Promoter Score), independiente del SUS.
  final int npsScore;

  final DateTime submittedAt;

  const UsabilitySurveyResponse({
    required this.uid,
    required this.susAnswers,
    required this.npsScore,
    required this.submittedAt,
  });

  /// Puntaje SUS de esta respuesta, 0-100 (fórmula estándar de Brooke):
  /// ítems impares (posiciones 0,2,4,6,8 en la lista) restan 1 a la
  /// respuesta; ítems pares (1,3,5,7,9) restan la respuesta a 5; se suma
  /// todo y se multiplica por 2.5.
  double get susScore {
    var total = 0;
    for (var i = 0; i < susAnswers.length; i++) {
      final answer = susAnswers[i];
      total += i.isEven ? (answer - 1) : (5 - answer);
    }
    return total * 2.5;
  }
}
