// test/presentation/widgets/admin/sus_histogram_chart_test.dart
//
// Estabilidad visual de SusHistogramChart: estado vacío (sin respuestas)
// y con datos (histograma dibujado sin lanzar excepciones).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/presentation/widgets/admin/sus_histogram_chart.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('Estabilidad visual: SusHistogramChart', () {
    testWidgets(
      'Escenario: sin respuestas, se muestra el estado vacío',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const SusHistogramChart(histogram: [0, 0, 0, 0, 0])),
        );

        expect(
          find.text('Nadie ha respondido la encuesta todavía.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con respuestas, se dibuja el histograma sin errores',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const SusHistogramChart(histogram: [1, 0, 2, 3, 4])),
        );
        await tester.pump(const Duration(milliseconds: 700));

        expect(
          find.text('Nadie ha respondido la encuesta todavía.'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
