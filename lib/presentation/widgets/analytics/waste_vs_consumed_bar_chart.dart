// lib/presentation/widgets/analytics/waste_vs_consumed_bar_chart.dart
//
// FASE 3 — Gráficos de Analíticas:
// Barras agrupadas por categoría: verde = consumido a tiempo,
// rojo/naranja = desperdiciado. Consume AnalyticsProvider directamente
// (mismo patrón que RecetasScreen/ShoppingListScreen consumen su provider),
// no recibe los datos por parámetro.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/category_waste_stats.dart';
import '../../providers/analytics_provider.dart';
import '../../utils/food_category_ui.dart';
import 'analytics_chart_helpers.dart';

class WasteVsConsumedBarChart extends StatelessWidget {
  const WasteVsConsumedBarChart({super.key});

  static const _consumedColor = Color(0xFF66BB6A); // verde
  static const _expiredColor = Color(0xFFEF5350); // rojo/naranja

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<AnalyticsProvider>().summary;
    final data = summary.categoryBreakdown;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Consumido a tiempo vs. desperdiciado',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Por categoría',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (data.isEmpty)
              const ChartEmptyState(
                message: 'Aún no hay suficientes datos por categoría.',
              )
            else
              SizedBox(
                height: 220,
                child: _BarChartBody(data: data),
              ),
            if (data.isNotEmpty) ...[
              const SizedBox(height: 12),
              const ChartLegend(
                items: [
                  (_consumedColor, 'Consumido a tiempo'),
                  (_expiredColor, 'Desperdiciado'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BarChartBody extends StatelessWidget {
  final List<CategoryWasteStats> data;

  const _BarChartBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxCount = data
        .map((c) => c.consumedOnTime > c.expired ? c.consumedOnTime : c.expired)
        .fold<int>(0, (a, b) => a > b ? a : b);
    // Techo del eje Y con margen, mínimo 4 para que barras pequeñas (1-2)
    // no se vean pegadas al tope del gráfico.
    final maxY = (maxCount < 4 ? 4 : maxCount) * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final stats = data[group.x.toInt()];
              final label = rodIndex == 0 ? 'A tiempo' : 'Vencido';
              return BarTooltipItem(
                '${stats.category.label}\n$label: ${rod.toY.toInt()}',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
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
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                final category = data[index].category;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(category.icon, size: 16, color: category.chartColor),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].consumedOnTime.toDouble(),
                  color: WasteVsConsumedBarChart._consumedColor,
                  width: 8,
                  borderRadius: BorderRadius.circular(2),
                ),
                BarChartRodData(
                  toY: data[i].expired.toDouble(),
                  color: WasteVsConsumedBarChart._expiredColor,
                  width: 8,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

