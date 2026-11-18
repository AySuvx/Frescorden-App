// Desglose del Net Promoter Score en sus 3 categorías (promotor, pasivo,
// detractor) del Panel Administrativo Global — complementa el índice NPS
// ya mostrado en la tarjeta numérica (ver AdminStats.npsPromoters/
// npsPassives/npsDetractors / UsabilitySurveyStats.compute).

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../analytics/analytics_chart_helpers.dart';
import 'admin_chart_card.dart';

class NpsBreakdownChart extends StatelessWidget {
  final int promoters;
  final int passives;
  final int detractors;

  static const _detractorColor = Color(0xFFEF5350); // rojo
  static const _passiveColor = Color(0xFFFFB74D); // ámbar
  static const _promoterColor = Color(0xFF66BB6A); // verde

  const NpsBreakdownChart({
    super.key,
    required this.promoters,
    required this.passives,
    required this.detractors,
  });

  @override
  Widget build(BuildContext context) {
    final total = promoters + passives + detractors;

    return AdminChartCard(
      title: 'Desglose del Net Promoter Score',
      subtitle: 'Detractores (0-6) · Pasivos (7-8) · Promotores (9-10)',
      child: total == 0
          ? const ChartEmptyState(
              message: 'Nadie ha respondido la encuesta todavía.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 180,
                  child: _Bars(
                    promoters: promoters,
                    passives: passives,
                    detractors: detractors,
                  ),
                ),
                const SizedBox(height: 12),
                const ChartLegend(
                  items: [
                    (_detractorColor, 'Detractores'),
                    (_passiveColor, 'Pasivos'),
                    (_promoterColor, 'Promotores'),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Bars extends StatelessWidget {
  final int promoters;
  final int passives;
  final int detractors;

  const _Bars({
    required this.promoters,
    required this.passives,
    required this.detractors,
  });

  @override
  Widget build(BuildContext context) {
    final values = [detractors, passives, promoters];
    final maxCount = values.fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxCount < 4 ? 4 : maxCount) * 1.2;
    final colors = [
      NpsBreakdownChart._detractorColor,
      NpsBreakdownChart._passiveColor,
      NpsBreakdownChart._promoterColor,
    ];
    final labels = ['Detractores', 'Pasivos', 'Promotores'];

    return BarChart(
      duration: const Duration(milliseconds: 600),
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${labels[group.x.toInt()]}\n${rod.toY.toInt()}',
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
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[index],
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
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i].toDouble(),
                  color: colors[i],
                  width: 36,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
