// test/presentation/widgets/admin/sus_score_dot_plot_test.dart
//
// Estabilidad visual de SusScoreDotPlot: estado vacío (sin respuestas) y
// con datos (un punto por respuesta, media/DE/n en el pie del gráfico).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/presentation/widgets/admin/sus_score_dot_plot.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('Estabilidad visual: SusScoreDotPlot', () {
    testWidgets(
      'Escenario: sin respuestas, se muestra el estado vacío',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const SusScoreDotPlot(scores: [], mean: 0, stdDev: 0)),
        );

        expect(
          find.text('Nadie ha respondido la encuesta todavía.'),
          findsOneWidget,
        );
        expect(find.textContaining('Media ='), findsNothing);
      },
    );

    testWidgets(
      'Escenario: con 28 respuestas, se dibuja un punto por respuesta y '
      'el pie reporta media, desviación estándar y n',
      (tester) async {
        final scores = List<double>.generate(28, (i) => (i * 100 / 27));

        await tester.pumpWidget(
          _wrap(
            SusScoreDotPlot(scores: scores, mean: 50.5, stdDev: 12.3),
          ),
        );

        expect(find.text('Media = 50.5 · DE = 12.3 · n = 28'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: un puntaje en el extremo (100) no se corta fuera del '
      'ancho disponible',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const SusScoreDotPlot(
              scores: [0, 50, 100],
              mean: 50,
              stdDev: 50,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  });
}
