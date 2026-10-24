// Línea de tendencia del ahorro mes a mes (AnalyticsSummary.monthlyHistory)
// — a diferencia del resto de "Analíticas" (una foto de los últimos 30
// días), esto responde "¿estoy mejorando o empeorando?". Curva suave +
// relleno en degradé + animación de entrada: mismo fl_chart que el resto
// de la pantalla, pero con el tratamiento visual que le falta a las demás.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/monthly_analytics.dart';
import '../../providers/analytics_provider.dart';
import '../../utils/currency_format.dart';
import 'analytics_chart_helpers.dart';

const _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

class SavingsTrendChart extends StatelessWidget {
  const SavingsTrendChart({super.key});

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<AnalyticsProvider>().summary;
    final data = summary.monthlyHistory;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tu ahorro mes a mes',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dinero salvado por no desperdiciar, por mes',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (data.length < 2)
              const ChartEmptyState(
                message: 'Necesitas al menos 2 meses de historial para ver '
                    'tu tendencia de ahorro.',
              )
            else
              SizedBox(
                height: 180,
                child: _TrendChartBody(data: data),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendChartBody extends StatelessWidget {
  final List<MonthlyAnalytics> data;

  const _TrendChartBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxY = data
        .map((m) => m.moneySavedCop)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final safeMaxY = (maxY == 0 ? 1 : maxY) * 1.2;

    return LineChart(
      duration: const Duration(milliseconds: 600),
      LineChartData(
        minY: 0,
        maxY: safeMaxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((spot) {
              final month = data[spot.x.toInt()].month;
              return LineTooltipItem(
                '${_mesesCortos[month.month - 1]}\n${spot.y.round().asCop}',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _mesesCortos[data[index].month.month - 1],
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            curveSmoothness: 0.3,
            color: colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: colorScheme.primary,
                strokeWidth: 2,
                strokeColor: colorScheme.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.primary.withValues(alpha: 0.28),
                  colorScheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
            spots: [
              for (var i = 0; i < data.length; i++)
                FlSpot(i.toDouble(), data[i].moneySavedCop.toDouble()),
            ],
          ),
        ],
      ),
    );
  }
}
