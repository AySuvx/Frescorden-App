// test/presentation/providers/usability_survey_provider_test.dart
//
// BDD de UsabilitySurveyProvider, con FakeUsabilitySurveyRepository
// (test/support/fake_repositories.dart) en vez de Firestore.

import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/presentation/providers/usability_survey_provider.dart';

import '../../support/fake_repositories.dart';

void main() {
  group('Historia de Usuario: Como responsable del piloto, quiero que los '
      'usuarios respondan la encuesta de usabilidad una sola vez', () {
    late FakeUsabilitySurveyRepository repo;
    late UsabilitySurveyProvider provider;

    setUp(() {
      repo = FakeUsabilitySurveyRepository();
      provider = UsabilitySurveyProvider(repo);
    });

    test(
      'Escenario: un uid que nunca respondió aparece como no respondido',
      () async {
        expect(await provider.hasSubmitted('uid-1'), isFalse);
      },
    );

    test(
      'Escenario: enviar la encuesta la registra en el repositorio y la '
      'marca como respondida',
      () async {
        final ok = await provider.submit(
          uid: 'uid-1',
          susAnswers: List.filled(10, 3),
          npsScore: 9,
        );

        expect(ok, isTrue);
        expect(repo.submittedResponses, hasLength(1));
        expect(repo.submittedResponses.first.uid, 'uid-1');
        expect(repo.submittedResponses.first.npsScore, 9);
        expect(await provider.hasSubmitted('uid-1'), isTrue);
        expect(provider.isSubmitting, isFalse);
        expect(provider.error, isNull);
      },
    );

    test(
      'Escenario: si el repositorio falla al enviar, se expone el error y '
      'no se lanza excepción (la pantalla decide qué mostrar)',
      () async {
        repo.submitError = Exception('sin conexión');

        final ok = await provider.submit(
          uid: 'uid-1',
          susAnswers: List.filled(10, 3),
          npsScore: 9,
        );

        expect(ok, isFalse);
        expect(provider.error, isNotNull);
        expect(provider.isSubmitting, isFalse);
        expect(repo.submittedResponses, isEmpty);
      },
    );
  });
}
