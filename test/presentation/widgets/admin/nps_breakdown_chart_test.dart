// test/presentation/widgets/admin/nps_breakdown_chart_test.dart
//
// Estabilidad visual de NpsBreakdownChart: estado vacío (sin respuestas)
// y con datos (las 3 barras + leyenda se dibujan sin excepciones).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/presentation/widgets/admin/nps_breakdown_chart.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('Estabilidad visual: NpsBreakdownChart', () {
    testWidgets(
      'Escenario: sin respuestas, se muestra el estado vacío',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const NpsBreakdownChart(promoters: 0, passives: 0, detractors: 0),
          ),
        );

        expect(
          find.text('Nadie ha respondido la encuesta todavía.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Escenario: con respuestas, se dibujan las 3 barras y la leyenda',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const NpsBreakdownChart(promoters: 5, passives: 2, detractors: 1),
          ),
        );
        await tester.pump(const Duration(milliseconds: 700));

        // Las etiquetas aparecen tanto en el eje X del gráfico como en la
        // leyenda — basta con comprobar que existen, no cuántas veces.
        expect(find.text('Detractores'), findsAtLeastNWidgets(1));
        expect(find.text('Pasivos'), findsAtLeastNWidgets(1));
        expect(find.text('Promotores'), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
