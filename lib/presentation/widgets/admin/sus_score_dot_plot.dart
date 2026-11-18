// Dispersión de los puntajes SUS individuales (0-100) del piloto — un
// punto por respuesta sobre un eje horizontal, con la media y una banda
// de ±1 desviación estándar superpuestas. Complementa a
// SusItemAveragesChart (que promedia por ítem): este muestra qué tan
// parecidas o distintas fueron las experiencias de los participantes
// entre sí, no solo el promedio global (ver UsabilitySurveyStats.susScores
// / stdDevSus).

import 'package:flutter/material.dart';
import '../analytics/analytics_chart_helpers.dart';
import 'admin_chart_card.dart';

class SusScoreDotPlot extends StatelessWidget {
  final List<double> scores;
  final double mean;
  final double stdDev;

  static const _dotColor = Color(0xFF26A69A);
  static const _bandColor = Color(0x2926A69A);
  static const _meanColor = Color(0xFFE64A19);

  const SusScoreDotPlot({
    super.key,
    required this.scores,
    required this.mean,
    required this.stdDev,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AdminChartCard(
      title: 'Dispersión de los puntajes SUS individuales',
      subtitle: 'Cada punto es una respuesta del piloto. La línea marca la '
          'media y la banda sombreada, ±1 desviación estándar.',
      child: scores.isEmpty
          ? const ChartEmptyState(
              message: 'Nadie ha respondido la encuesta todavía.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DotStrip(scores: scores, mean: mean, stdDev: stdDev),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('0', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                    const Spacer(),
                    Text('50', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                    const Spacer(),
                    Text('100', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Media = ${mean.toStringAsFixed(1)} · DE = '
                  '${stdDev.toStringAsFixed(1)} · n = ${scores.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
    );
  }
}

class _DotStrip extends StatelessWidget {
  final List<double> scores;
  final double mean;
  final double stdDev;

  const _DotStrip({
    required this.scores,
    required this.mean,
    required this.stdDev,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          double xFor(double score) => (score.clamp(0, 100) / 100) * width;

          final bandLow = (mean - stdDev).clamp(0.0, 100.0);
          final bandHigh = (mean + stdDev).clamp(0.0, 100.0);
          final bandLeft = xFor(bandLow);
          final bandWidth = (xFor(bandHigh) - bandLeft).clamp(0.0, width);

          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 30,
                child: Container(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              Positioned(
                left: bandLeft,
                width: bandWidth,
                top: 0,
                bottom: 0,
                child: Container(color: SusScoreDotPlot._bandColor),
              ),
              Positioned(
                left: (xFor(mean) - 1).clamp(0.0, width - 2),
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: SusScoreDotPlot._meanColor),
              ),
              for (var i = 0; i < scores.length; i++)
                Positioned(
                  left: (xFor(scores[i]) - 4).clamp(0.0, width - 8),
                  top: 26.0 - (i % 5) * 5.0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: SusScoreDotPlot._dotColor,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
