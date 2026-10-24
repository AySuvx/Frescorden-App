// test/presentation/widgets/admin/sus_item_averages_chart_test.dart
//
// Estabilidad visual de SusItemAveragesChart: estado vacío (sin
// respuestas) y con datos (una fila por ítem, con su promedio formateado).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frescorden/presentation/widgets/admin/sus_item_averages_chart.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('Estabilidad visual: SusItemAveragesChart', () {
    testWidgets(
      'Escenario: sin respuestas, se muestra el estado vacío',
      (tester) async {
        await tester.pumpWidget(
          const _TestHost(itemAverages: []),
        );

        expect(
          find.text('Nadie ha respondido la encuesta todavía.'),
          findsOneWidget,
        );
        expect(find.textContaining('Ítem'), findsNothing);
      },
    );

    testWidgets(
      'Escenario: con 10 ítems, se dibuja una fila por ítem con su '
      'promedio formateado a un decimal',
      (tester) async {
        final averages = List.generate(10, (i) => i + 1.0);

        await tester.pumpWidget(_TestHost(itemAverages: averages));

        expect(find.text('Ítem 1'), findsOneWidget);
        expect(find.text('Ítem 10'), findsOneWidget);
        expect(find.text('1.0'), findsOneWidget);
        expect(find.text('10.0'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _TestHost extends StatelessWidget {
  final List<double> itemAverages;

  const _TestHost({required this.itemAverages});

  @override
  Widget build(BuildContext context) {
    return _wrap(SusItemAveragesChart(itemAverages: itemAverages));
  }
}
