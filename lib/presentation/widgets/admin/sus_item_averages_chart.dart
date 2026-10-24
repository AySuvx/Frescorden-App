// Promedio por ítem del SUS (10 preguntas, escala Likert 1-5) del Panel
// Administrativo Global — barras horizontales simples (sin fl_chart,
// suficiente para 10 filas finas) que permiten identificar qué aspecto de
// usabilidad puntúa peor/mejor, en vez de solo el puntaje SUS agregado
// (ver AdminStats.susItemAverages / UsabilitySurveyStats.compute).

import 'package:flutter/material.dart';
import '../analytics/analytics_chart_helpers.dart';

class SusItemAveragesChart extends StatelessWidget {
  final List<double> itemAverages;

  static const _barColor = Color(0xFF26A69A); // verde azulado

  const SusItemAveragesChart({super.key, required this.itemAverages});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Promedio por ítem del SUS',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Escala 1 (en desacuerdo) a 5 (de acuerdo) — ítem 1 a 10, '
              'mismo orden del instrumento original',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (itemAverages.isEmpty)
              const ChartEmptyState(
                message: 'Nadie ha respondido la encuesta todavía.',
              )
            else
              for (var i = 0; i < itemAverages.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ItemBar(index: i, average: itemAverages[i]),
                ),
          ],
        ),
      ),
    );
  }
}

class _ItemBar extends StatelessWidget {
  final int index;
  final double average;

  const _ItemBar({required this.index, required this.average});

  @override
  Widget build(BuildContext context) {
    final fraction = (average / 5).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            'Ítem ${index + 1}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 14, color: Colors.grey.withValues(alpha: 0.15)),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(
                    height: 14,
                    color: SusItemAveragesChart._barColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            average.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
