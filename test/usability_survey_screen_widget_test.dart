// test/usability_survey_screen_widget_test.dart
//
// Widget tests de estabilidad visual de UsabilitySurveyScreen: las 10
// afirmaciones del SUS + la pregunta de NPS, usando AuthProvider/
// UsabilitySurveyProvider reales con fakes (ver test/support/fake_repositories.dart)
// en vez de Firestore.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:frescorden/domain/entities/app_user.dart';
import 'package:frescorden/presentation/providers/auth_provider.dart';
import 'package:frescorden/presentation/providers/usability_survey_provider.dart';
import 'package:frescorden/presentation/screens/usability_survey_screen.dart';
import 'package:frescorden/presentation/widgets/common/primary_button.dart';

import 'support/fake_repositories.dart';

Widget _wrap(AuthProvider authProvider, UsabilitySurveyProvider surveyProvider) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<UsabilitySurveyProvider>.value(value: surveyProvider),
      ],
      child: const UsabilitySurveyScreen(),
    ),
  );
}

/// Viewport muy alto: las 10 afirmaciones del SUS + la pregunta de NPS no
/// caben en el tamaño de ventana default de flutter_test (800x600 lógicos)
/// — con ese tamaño, el ListView (no-builder, pero igual sujeto a
/// culling de Sliver) ni siquiera monta los ítems fuera de vista, y
/// tocarlos falla con "outside bounds" en vez de solo no encontrarlos.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('Estabilidad visual: UsabilitySurveyScreen', () {
    late FakeAuthRepository authRepo;
    late FakeUsabilitySurveyRepository surveyRepo;
    late AuthProvider authProvider;
    late UsabilitySurveyProvider surveyProvider;

    setUp(() {
      authRepo = FakeAuthRepository()
        ..currentUser = const AppUser(uid: 'uid-1', emailVerified: true);
      surveyRepo = FakeUsabilitySurveyRepository();
      authProvider = AuthProvider(authRepo);
      surveyProvider = UsabilitySurveyProvider(surveyRepo);
    });

    testWidgets(
      'Escenario: la encuesta renderiza las 10 afirmaciones y el botón '
      'Enviar empieza deshabilitado',
      (tester) async {
        _useTallViewport(tester);
        await tester.pumpWidget(_wrap(authProvider, surveyProvider));
        await tester.pump();

        expect(find.textContaining('1. '), findsOneWidget);
        expect(find.textContaining('10. '), findsOneWidget);
        final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
        expect(button.onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: al responder las 10 afirmaciones y el NPS, el botón '
      'Enviar se habilita y al tocarlo se envía la encuesta',
      (tester) async {
        _useTallViewport(tester);
        await tester.pumpWidget(_wrap(authProvider, surveyProvider));
        await tester.pump();

        // Responde "De acuerdo" (score 4) a cada una de las 10 afirmaciones.
        final cuatros = find.text('4');
        for (var i = 0; i < 10; i++) {
          await tester.tap(cuatros.at(i));
          await tester.pump();
        }
        // NPS: elige 9 (ChoiceChip con esa etiqueta, no confundir con los
        // botones Likert de arriba que ya se agotaron).
        await tester.tap(find.widgetWithText(ChoiceChip, '9'));
        await tester.pump();

        final button = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
        expect(button.onPressed, isNotNull);

        await tester.tap(find.byType(PrimaryButton));
        await tester.pump(const Duration(milliseconds: 300));

        expect(surveyRepo.submittedResponses, hasLength(1));
        expect(surveyRepo.submittedResponses.first.uid, 'uid-1');
        expect(surveyRepo.submittedResponses.first.npsScore, 9);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
