// Histograma de puntajes SUS (System Usability Scale, Brooke 1986) del
// Panel Administrativo Global — una barra por franja de 20 puntos, para
// visualizar cómo se distribuyen las respuestas en vez de solo mostrar el
// promedio (ver AdminStats.susScoreHistogram /
// UsabilitySurveyStats.compute).

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../analytics/analytics_chart_helpers.dart';

class SusHistogramChart extends StatelessWidget {
  final List<int> histogram;

  static const _labels = ['0-20', '20-40', '40-60', '60-80', '80-100'];
  static const _barColor = Color(0xFF5C6BC0); // índigo

  const SusHistogramChart({super.key, required this.histogram});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = histogram.fold<int>(0, (a, b) => a + b);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribución de puntajes SUS',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cuántas respuestas cayeron en cada franja de 0 a 100',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (total == 0)
              const ChartEmptyState(
                message: 'Nadie ha respondido la encuesta todavía.',
              )
            else
              SizedBox(
                height: 200,
                child: _Histogram(histogram: histogram),
              ),
          ],
        ),
      ),
    );
  }
}

class _Histogram extends StatelessWidget {
  final List<int> histogram;

  const _Histogram({required this.histogram});

  @override
  Widget build(BuildContext context) {
    final maxCount = histogram.fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxCount < 4 ? 4 : maxCount) * 1.2;

    return BarChart(
      duration: const Duration(milliseconds: 600),
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${SusHistogramChart._labels[group.x.toInt()]}\n'
                '${rod.toY.toInt()} respuesta(s)',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (maxY / 4).clamp(1, double.infinity),
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= SusHistogramChart._labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    SusHistogramChart._labels[index],
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        barGroups: [
          for (var i = 0; i < histogram.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: histogram[i].toDouble(),
                  color: SusHistogramChart._barColor,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
